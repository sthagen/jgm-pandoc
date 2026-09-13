{-# LANGUAGE OverloadedStrings, ScopedTypeVariables #-}
{-# LANGUAGE ViewPatterns      #-}
{-# OPTIONS_GHC -fno-warn-type-defaults #-}
{- |
Module      : Text.Pandoc.ImageSize
Copyright   : Copyright (C) 2011-2024 John MacFarlane
License     : GNU GPL, version 2 or above

Maintainer  : John MacFarlane <jgm@berkeley.edu>
Stability   : alpha
Portability : portable

Functions for determining the size of a PNG, JPEG, or GIF image.
-}
module Text.Pandoc.ImageSize ( ImageType(..)
                             , ImageSize(..)
                             , imageType
                             , imageSize
                             , sizeInPixels
                             , sizeInPoints
                             , desiredSizeInPoints
                             , Dimension(..)
                             , Direction(..)
                             , dimension
                             , lengthToDim
                             , scaleDimension
                             , inInch
                             , inPixel
                             , inPoints
                             , inEm
                             , numUnit
                             , showInInch
                             , showInPixel
                             , showFl
                             ) where
import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as B
import qualified Data.ByteString.Lazy as BL
import Data.Binary.Get
import Data.Bits ((.&.), shiftR, shiftL)
import Data.Word (Word32)
import Data.Maybe (fromMaybe)
import Data.Char (isDigit)
import Control.Monad
import Text.Pandoc.Shared (safeRead)
import Data.Default (Default)
import Numeric (showFFloat)
import Text.Pandoc.Definition
import Text.Pandoc.Options
import qualified Text.Pandoc.UTF8 as UTF8
import Text.Pandoc.XML.Light hiding (Attr)
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Encoding as TE
import Control.Applicative
import qualified Data.Attoparsec.ByteString as AW
import qualified Data.Attoparsec.ByteString.Char8 as A
import qualified Codec.Picture.Metadata as Metadata
import Codec.Picture (decodeImageWithMetadata)
import qualified Codec.Compression.Zlib.Internal as Zlib
-- import Debug.Trace

-- quick and dirty functions to get image sizes

data ImageType = Png | Gif | Jpeg | Svg | Pdf | Eps | Emf | Tiff | Webp | Avif
                 deriving (Show, Eq)
data Direction = Width | Height
instance Show Direction where
  show Width  = "width"
  show Height = "height"

data Dimension = Pixel Integer
               | Centimeter Double
               | Millimeter Double
               | Inch Double
               | Point Double
               | Pica Double
               | Percent Double
               | Em Double
               deriving Eq

instance Show Dimension where
  show (Pixel a)      = show a              ++ "px"
  show (Centimeter a) = T.unpack (showFl a) ++ "cm"
  show (Millimeter a) = T.unpack (showFl a) ++ "mm"
  show (Inch a)       = T.unpack (showFl a) ++ "in"
  show (Point a)      = T.unpack (showFl a) ++ "pt"
  show (Pica a)       = T.unpack (showFl a) ++ "pc"
  show (Percent a)    = show a              ++ "%"
  show (Em a)         = T.unpack (showFl a) ++ "em"

data ImageSize = ImageSize{
                     pxX   :: Integer
                   , pxY   :: Integer
                   , dpiX  :: Integer
                   , dpiY  :: Integer
                   } deriving (Read, Show, Eq)
instance Default ImageSize where
  def = ImageSize 300 200 72 72

showFl :: (RealFloat a) => a -> T.Text
showFl a = removeExtra0s $ T.pack $ showFFloat (Just 5) a ""

removeExtra0s :: T.Text -> T.Text
removeExtra0s s = case T.dropWhileEnd (=='0') s of
  (T.unsnoc -> Just (xs, '.')) -> xs
  xs                           -> xs

dropBOM :: ByteString -> ByteString
dropBOM bs =
 if "\xEF\xBB\xBF" `B.isPrefixOf` bs
    then B.drop 3 bs
    else bs

imageType :: ByteString -> Maybe ImageType
imageType img = case B.take 4 img of
                     "\x89\x50\x4e\x47" -> return Png
                     "\x47\x49\x46\x38" -> return Gif
                     "\x49\x49\x2a\x00" -> return Tiff
                     "\x4D\x4D\x00\x2a" -> return Tiff
                     "\xff\xd8\xff\xdb" -> return Jpeg  -- JPEG without application segment -- see p.32 in https://www.w3.org/Graphics/JPEG/itu-t81.pdf (and https://gist.github.com/leommoore/f9e57ba2aa4bf197ebc5?permalink_comment_id=3863054#gistcomment-3863054)
                     _ | B.take 3 img == "\xff\xd8\xff"
                          && (let byte4 = B.take 1 (B.drop 3 img)
                              in byte4 >= "\xe0" && byte4 <= "\xef")  -- JPEG with application segment
                                        -> return Jpeg
                     "%PDF"             -> return Pdf
                     "<svg"             -> return Svg
                     "<?xm"
                       | findSvgTag img
                                        -> return Svg
                     "%!PS"
                       |  B.take 4 (B.drop 1 $ B.dropWhile (/=' ') img) == "EPSF"
                                        -> return Eps
                     "\x01\x00\x00\x00"
                       | B.take 4 (B.drop 40 img) == " EMF"
                                        -> return Emf
                     "\xEF\xBB\xBF<" -- BOM before svg
                          -> imageType (B.drop 3 img)
                     "RIFF"
                       | B.take 4 (B.drop 8 img) == "WEBP"
                                        -> return Webp
                     _ | B.take 4 (B.drop 4 img) == "ftyp"
                          -- require the AVIF brand, so that other
                          -- ISO media (mp4, mov, heic...) is excluded:
                          && (B.take 4 (B.drop 8 img) == "avif" ||
                              B.take 4 (B.drop 8 img) == "avis")
                                        -> return Avif
                     _ -> mzero

-- | Check for the presence of an @<svg@ (or @<SVG@) tag, in a
-- single pass over the file.
findSvgTag :: ByteString -> Bool
findSvgTag img = case B.elemIndex '<' img of
  Nothing -> False
  Just i ->
    case B.drop (i + 1) img of
      rest | "svg" `B.isPrefixOf` rest -> True
           | "SVG" `B.isPrefixOf` rest -> True
           | otherwise -> findSvgTag rest

imageSize :: WriterOptions -> ByteString -> Either T.Text ImageSize
imageSize opts img = checkDpi <$>
  case imageType img of
       Just Png  -> case pngSize img of
                      Just sz -> Right sz
                      -- fall back to the full decoder if the header
                      -- scan fails:
                      Nothing -> getSize img
       Just Gif  -> getSize img
       Just Jpeg -> case jpegSize img of
                      Just sz -> Right sz
                      -- fall back to the full decoder if the header
                      -- scan fails:
                      Nothing -> getSize img
       Just Tiff -> getSize img
       Just Svg  -> mbToEither "could not determine SVG size" $ svgSize opts img
       Just Eps  -> mbToEither "could not determine EPS size" $ epsSize img
       Just Pdf  -> mbToEither "could not determine PDF size" $ pdfSize img
       Just Emf  -> mbToEither "could not determine EMF size" $ emfSize img
       Just Webp -> mbToEither "could not determine WebP size" $ webpSize opts img
       Just Avif -> mbToEither "could not determine AVIF size" $ avifSize opts img
       Nothing   -> Left "could not determine image type"
  where mbToEither msg Nothing  = Left msg
        mbToEither _   (Just x) = Right x
        -- see #6880, some defective JPEGs may encode dpi 0, so default to 72
        -- if that value is 0 or negative
        checkDpi size =
          size{ dpiX = if dpiX size <= 0 then 72 else dpiX size
              , dpiY = if dpiY size <= 0 then 72 else dpiY size }


sizeInPixels :: ImageSize -> (Integer, Integer)
sizeInPixels s = (pxX s, pxY s)

-- | Calculate (height, width) in points using the image file's dpi metadata,
-- using 72 Points == 1 Inch.
sizeInPoints :: ImageSize -> (Double, Double)
sizeInPoints s = (pxXf * 72 / dpiXf, pxYf * 72 / dpiYf)
  where
    pxXf  = fromIntegral $ pxX s
    pxYf  = fromIntegral $ pxY s
    dpiXf = fromIntegral $ dpiX s
    dpiYf = fromIntegral $ dpiY s

-- | Calculate (height, width) in points, considering the desired dimensions in the
-- attribute, while falling back on the image file's dpi metadata if no dimensions
-- are specified in the attribute (or only dimensions in percentages).
desiredSizeInPoints :: WriterOptions -> Attr -> ImageSize -> (Double, Double)
desiredSizeInPoints opts attr s =
  case (getDim Width, getDim Height) of
    (Just w, Just h)   -> (w, h)
    (Just w, Nothing)  -> (w, w / ratio)
    (Nothing, Just h)  -> (h * ratio, h)
    (Nothing, Nothing) -> sizeInPoints s
  where
    ratio = fromIntegral (pxX s) / fromIntegral (pxY s)
    getDim dir = case dimension dir attr of
                   Just (Percent _) -> Nothing
                   Just dim         -> Just $ inPoints opts dim
                   Nothing          -> Nothing

inPoints :: WriterOptions -> Dimension -> Double
inPoints opts dim = 72 * inInch opts dim

inEm :: WriterOptions -> Dimension -> Double
inEm opts dim = (64/11) * inInch opts dim

inInch :: WriterOptions -> Dimension -> Double
inInch opts dim =
  case dim of
    (Pixel a)      -> fromIntegral a / fromIntegral (writerDpi opts)
    (Centimeter a) -> a * 0.3937007874
    (Millimeter a) -> a * 0.03937007874
    (Inch a)       -> a
    (Point a)      -> (a / 72)
    (Pica a)       -> (a / 6)
    (Percent _)    -> 0
    (Em a)         -> a * (11/64)

inPixel :: WriterOptions -> Dimension -> Integer
inPixel opts dim =
  case dim of
    (Pixel a)      -> a
    _              -> floor (dpi * inInch opts dim)
  where
    dpi = fromIntegral $ writerDpi opts

-- | Convert a Dimension to Text denoting its equivalent in inches, for example "2.00000".
-- Note: Dimensions in percentages are converted to the empty string.
showInInch :: WriterOptions -> Dimension -> T.Text
showInInch _ (Percent _) = ""
showInInch opts dim = showFl $ inInch opts dim

-- | Convert a Dimension to Text denoting its equivalent in pixels, for example "600".
-- Note: Dimensions in percentages are converted to the empty string.
showInPixel :: WriterOptions -> Dimension -> T.Text
showInPixel _ (Percent _) = ""
showInPixel opts dim = T.pack $ show $ inPixel opts dim

-- | Maybe split a string into a leading number and trailing unit, e.g. "3cm" to Just (3.0, "cm").
-- Whitespace between the number and the unit is ignored.
numUnit :: T.Text -> Maybe (Double, T.Text)
numUnit s =
  let (nums, unit) = T.span (\c -> isDigit c || ('.'==c)) s
  in (\n -> (n, T.stripStart unit)) <$> safeRead nums

-- | Scale a dimension by a factor.
scaleDimension :: Double -> Dimension -> Dimension
scaleDimension factor dim =
  case dim of
        Pixel x      -> Pixel (round $ factor * fromIntegral x)
        Centimeter x -> Centimeter (factor * x)
        Millimeter x -> Millimeter (factor * x)
        Inch x       -> Inch (factor * x)
        Point x      -> Point (factor * x)
        Pica x       -> Pica (factor * x)
        Percent x    -> Percent (factor * x)
        Em x         -> Em (factor * x)

-- | Read a Dimension from an Attr attribute.
-- `dimension Width attr` might return `Just (Pixel 3)` or for example `Just (Centimeter 2.0)`, etc.
dimension :: Direction -> Attr -> Maybe Dimension
dimension dir (_, _, kvs) =
  case dir of
    Width  -> extractDim "width"
    Height -> extractDim "height"
  where
    extractDim key = lookup key kvs >>= lengthToDim

lengthToDim :: T.Text -> Maybe Dimension
lengthToDim s = numUnit s >>= uncurry toDim
  where
    toDim a "cm"   = Just $ Centimeter a
    toDim a "mm"   = Just $ Millimeter a
    toDim a "in"   = Just $ Inch a
    toDim a "inch" = Just $ Inch a
    toDim a "%"    = Just $ Percent a
    toDim a "px"   = Just $ Pixel (floor a::Integer)
    toDim a ""     = Just $ Pixel (floor a::Integer)
    toDim a "pt"   = Just $ Point a
    toDim a "pc"   = Just $ Pica a
    toDim a "em"   = Just $ Em a
    toDim _ _      = Nothing

epsSize :: ByteString -> Maybe ImageSize
epsSize img = do
  let ls = takeWhile ("%" `B.isPrefixOf`) $ B.lines img
  let ls' = dropWhile (not . ("%%BoundingBox:" `B.isPrefixOf`)) ls
  case ls' of
       []    -> mzero
       (x:_) -> case B.words x of
                     [_, llx, lly, urx, ury] -> do
                        llx' <- safeRead $ TE.decodeUtf8Lenient llx
                        lly' <- safeRead $ TE.decodeUtf8Lenient lly
                        urx' <- safeRead $ TE.decodeUtf8Lenient urx
                        ury' <- safeRead $ TE.decodeUtf8Lenient ury
                        return ImageSize{
                            pxX  = urx' - llx'
                          , pxY  = ury' - lly'
                          , dpiX = 72
                          , dpiY = 72 }
                     _ -> mzero

pdfSize :: ByteString -> Maybe ImageSize
pdfSize img =
  case A.parseOnly pPdfSize img of
    Left _   -> Nothing
    Right sz -> Just sz

pPdfSize :: A.Parser ImageSize
pPdfSize =
  (A.takeWhile1 (/= '/') *> pPdfSize)
  <|>
  (do A.string "/MediaBox"
      A.skipSpace
      A.char8 '['
      A.skipSpace
      [x1,y1,x2,y2] <- A.count 4 $ do
        A.skipSpace
        raw <- A.many1 $ A.satisfy (\c -> isDigit c || c == '.')
        case safeRead $ T.pack raw of
          Just (r :: Double) -> return $ floor r
          Nothing            -> mzero
      A.skipSpace
      A.char8 ']'
      return $ ImageSize{
              pxX  = x2 - x1
            , pxY  = y2 - y1
            , dpiX = 72
            , dpiY = 72 }
  )
  <|> -- if we encounter a compressed object stream, uncompress it (#10902)
  (do A.string "/Type"
      A.skipSpace
      A.string "/ObjStm"
      _ <- A.manyTill pLine (A.string "stream" *> pEol)
      stream <- pTakeUntil "endstream"
      case A.parseOnly pPdfSize <$> safeDecompress stream of
        Just (Right is) -> pure is
        _ -> pPdfSize)
  <|>
  (A.char '/' *> pPdfSize)
 where
   iseol '\r' = True
   iseol '\n' = True
   iseol _ = False
   pEol = A.satisfy iseol *> A.skipMany (A.satisfy iseol)
   pLine = A.takeWhile (not . iseol) <* pEol

-- | Consume input up to and including the first occurrence of the
-- (non-empty) terminator, returning what precedes it.  Unlike
-- @manyTill anyWord8@, this consumes chunks at a time.
pTakeUntil :: ByteString -> A.Parser ByteString
pTakeUntil terminator = B.concat . reverse <$> go []
 where
  go acc = do
    chunk <- A.takeWhile (/= B.head terminator)
    let acc' = chunk : acc
    (A.string terminator *> pure acc')
      <|> (do c <- A.take 1
              go (c : acc'))

-- | Decompress a zlib stream, returning Nothing on malformed input.
-- ('Codec.Compression.Zlib.decompress' would instead throw an
-- exception from pure code when the corrupt part of its lazy result
-- is forced.)
safeDecompress :: ByteString -> Maybe ByteString
safeDecompress bs = fmap B.concat $
  Zlib.foldDecompressStreamWithInput
    (\chunk rest -> (chunk :) <$> rest)
    (const (Just []))
    (const Nothing)
    (Zlib.decompressST Zlib.zlibFormat Zlib.defaultDecompressParams)
    (BL.fromStrict bs)

-- | Extract PNG size from the IHDR and pHYs chunks, without
-- decoding any image data.  (For paletted PNGs, JuicyPixels decodes
-- the whole image before returning metadata.)
pngSize :: ByteString -> Maybe ImageSize
pngSize img =
  case runGetOrFail pPngSize (BL.fromStrict img) of
    Left _ -> Nothing
    Right (_, _, sz) -> Just sz
 where
  pPngSize = do
    skip 8  -- signature
    -- the IHDR chunk always comes first:
    ihdrLen <- getWord32be
    ihdr <- getByteString 4
    when (ihdr /= "IHDR" || ihdrLen < 13) $ fail "IHDR chunk not found"
    w <- getWord32be
    h <- getWord32be
    skip (fromIntegral ihdrLen - 8 + 4)  -- rest of chunk and CRC
    (dx, dy) <- findPhys
    return ImageSize{ pxX = toInteger w, pxY = toInteger h
                    , dpiX = dx, dpiY = dy }
  -- scan the following chunks for pHYs:
  findPhys = do
    done <- isEmpty
    if done
       then return (72, 72)
       else do
         len <- getWord32be
         typ <- getByteString 4
         case typ of
           "pHYs" -> do
             ppuX <- getWord32be
             ppuY <- getWord32be
             unit <- getWord8
             return $ if unit == 1  -- pixels per meter
                         then (dpmToDpi (toInteger ppuX),
                               dpmToDpi (toInteger ppuY))
                         else (72, 72)
           "IDAT" -> return (72, 72)  -- pHYs must precede image data
           "IEND" -> return (72, 72)
           _ -> skip (fromIntegral len + 4) *> findPhys

-- | Convert dots per meter to dots per inch, using the same integer
-- arithmetic as JuicyPixels for consistency.
dpmToDpi :: Integer -> Integer
dpmToDpi z = z * 254 `div` 10000

-- | Extract JPEG size from the header, without decoding any image
-- data.  Scans the marker segments preceding the entropy-coded data
-- for a start-of-frame marker (which gives the dimensions in pixels)
-- and JFIF APP0 and Exif APP1 segments (which give the resolution).
jpegSize :: ByteString -> Maybe ImageSize
jpegSize img =
  case runGetOrFail (skip 2 *> scanSegments Nothing Nothing)
         (BL.fromStrict img) of
    Left _ -> Nothing
    Right (_, _, sz) -> Just sz
 where
  scanSegments jfifDpi exifDpi = do
    ff <- getWord8
    when (ff /= 0xff) $ fail "malformed JPEG segment"
    marker <- skipFill
    scanSegment marker jfifDpi exifDpi

  -- extra 0xff bytes before a marker are padding:
  skipFill = do
    b <- getWord8
    if b == 0xff then skipFill else return b

  scanSegment marker jfifDpi exifDpi
    -- start of frame (baseline, progressive, etc.); C4, C8, and CC
    -- in this range are entropy-coding markers, not SOF:
    | marker >= 0xc0 && marker <= 0xcf
      && marker `notElem` [0xc4, 0xc8, 0xcc] = do
        skip 3  -- segment length and sample precision
        h <- getWord16be
        w <- getWord16be
        -- as in JuicyPixels, Exif resolution overrides JFIF:
        let (dx, dy) = fromMaybe (fromMaybe (72, 72) jfifDpi) exifDpi
        return ImageSize{ pxX = toInteger w, pxY = toInteger h
                        , dpiX = dx, dpiY = dy }
    | marker == 0xd9 || marker == 0xda =
        fail "no SOF marker before image data"  -- EOI or SOS
    | (marker >= 0xd0 && marker <= 0xd7) || marker == 0x01 =
        scanSegments jfifDpi exifDpi  -- markers without a payload
    | otherwise = do
        len <- getWord16be
        when (len < 2) $ fail "invalid segment length"
        let n = fromIntegral len - 2
        case marker of
          0xe0 -> do  -- APP0 (JFIF)
            body <- getByteString n
            scanSegments (jfifDensity body <|> jfifDpi) exifDpi
          0xe1 -> do  -- APP1 (Exif)
            body <- getByteString n
            scanSegments jfifDpi (exifDensity body <|> exifDpi)
          _ -> skip n *> scanSegments jfifDpi exifDpi

-- | Pixel density from the body of a JFIF APP0 segment.
jfifDensity :: ByteString -> Maybe (Integer, Integer)
jfifDensity body = do
  guard $ "JFIF\0" `B.isPrefixOf` body
  -- after the identifier and 2-byte version: density units,
  -- horizontal density, vertical density
  (units, x, y) <- getAt 7 ((,,) <$> getWord8 <*> getWord16be <*> getWord16be)
                     body
  case units of
    1 -> Just (toInteger x, toInteger y)  -- dots per inch
    2 -> Just (dpcmToDpi (toInteger x), dpcmToDpi (toInteger y))  -- per cm
    _ -> Nothing

-- | Resolution from the TIFF structure in the body of an Exif APP1
-- segment.
exifDensity :: ByteString -> Maybe (Integer, Integer)
exifDensity body = do
  guard $ "Exif\0\0" `B.isPrefixOf` body
  let tiff = B.drop 6 body  -- offsets are relative to the TIFF header
  (w16, w32) <- case B.take 2 tiff of
    "II" -> Just (getWord16le, getWord32le)
    "MM" -> Just (getWord16be, getWord32be)
    _    -> Nothing
  ifd <- fromIntegral <$> getAt 4 w32 tiff
  n <- fromIntegral <$> getAt ifd w16 tiff
  entries <- mapM (\i -> do let off = ifd + 2 + 12 * i
                            tag <- getAt off w16 tiff
                            return (tag, off))
                  [0 .. n - 1 :: Int]
  -- resolution unit (SHORT, stored inline in the value field):
  -- 2 = inches, 3 = centimeters
  unit <- lookup 0x0128 entries >>= \off -> getAt (off + 8) w16 tiff
  toDpi <- case unit of
             2 -> Just id
             3 -> Just dpcmToDpi
             _ -> Nothing
  let resolution tag = do
        off <- lookup tag entries
        -- the value field holds the offset of the RATIONAL value:
        valOff <- fromIntegral <$> getAt (off + 8) w32 tiff
        num <- getAt valOff w32 tiff
        den <- getAt (valOff + 4) w32 tiff
        guard $ den /= 0
        return $ toDpi (toInteger num `div` toInteger den)
  x <- resolution 0x011a  -- XResolution
  y <- resolution 0x011b  -- YResolution
  return (x, y)

-- | Convert dots per centimeter to dots per inch, using the same
-- integer arithmetic as JuicyPixels for consistency.
dpcmToDpi :: Integer -> Integer
dpcmToDpi z = z * 254 `div` 100

-- | Run a 'Get' parser at the given offset in a strict ByteString,
-- returning Nothing if it fails (e.g. by running out of input).
getAt :: Int -> Get a -> ByteString -> Maybe a
getAt off g bs
  | off < 0 = Nothing
  | otherwise = case runGetOrFail (skip off *> g) (BL.fromStrict bs) of
      Left _ -> Nothing
      Right (_, _, x) -> Just x

getSize :: ByteString -> Either T.Text ImageSize
getSize img =
  case decodeImageWithMetadata img of
    Left e -> Left (T.pack e)
    Right (_, meta) -> do
      pxx <- maybe (Left "Could not determine width") Right $
                   Metadata.lookup Metadata.Width meta
      pxy <- maybe (Left "Could not determine height") Right $
                   Metadata.lookup Metadata.Height meta
      dpix <- maybe (Right 72) Right $ Metadata.lookup Metadata.DpiX meta
      dpiy <- maybe (Right 72) Right $ Metadata.lookup Metadata.DpiY meta
      return $ ImageSize
                { pxX = fromIntegral pxx
                , pxY = fromIntegral pxy
                , dpiX = fromIntegral dpix
                , dpiY = fromIntegral dpiy }

svgSize :: WriterOptions -> ByteString -> Maybe ImageSize
svgSize opts img = do
  doc <- either (const mzero) return $ parseXMLElement
                                     $ TL.fromStrict $ UTF8.toText $ dropBOM img
  let viewboxSize = do
        vb <- findAttrBy (== QName "viewBox" Nothing Nothing) doc
        -- per the SVG spec, the numbers are separated by whitespace
        -- and/or a comma, and may be fractional:
        [_,_,w,h] <- mapM safeRead $ T.words $
                       T.map (\c -> if c == ',' then ' ' else c) vb
        return (floor (w :: Double), floor (h :: Double))
  let dpi = fromIntegral $ writerDpi opts
  let dirToInt dir = do
        dim <- findAttrBy (== QName dir Nothing Nothing) doc >>= lengthToDim
        case dim of
           Percent _ -> mzero
           _ -> pure $ inPixel opts dim
  w <- dirToInt "width" <|> (fst <$> viewboxSize)
  h <- dirToInt "height" <|> (snd <$> viewboxSize)
  return ImageSize {
    pxX  = w
  , pxY  = h
  , dpiX = dpi
  , dpiY = dpi
  }

emfSize :: ByteString -> Maybe ImageSize
emfSize img =
  let
    parseheader = runGetOrFail $ do
      skip 0x18             -- 0x00
      -- the frame bounds are signed, measured in 1/100 of a millimetre:
      frameL <- getInt32le  -- 0x18
      frameT <- getInt32le  -- 0x1C
      frameR <- getInt32le  -- 0x20
      frameB <- getInt32le  -- 0x24
      skip 0x20             -- 0x28
      deviceX <- getWord32le  -- 0x48 pixels of reference device
      deviceY <- getWord32le  -- 0x4C
      mmX <- getWord32le      -- 0x50 real mm of reference device (always 320*240?)
      mmY <- getWord32le      -- 0x54
      -- end of header
      -- guard against division by zero below; since the ImageSize
      -- fields are lazy, the exception would escape runGetOrFail
      when (mmX == 0 || mmY == 0) $
        fail "EMF header has zero-size reference device"
      -- compute with Integers to avoid Word32 overflow:
      let
        w = (toInteger deviceX * (toInteger frameR - toInteger frameL))
              `quot` (toInteger mmX * 100)
        h = (toInteger deviceY * (toInteger frameB - toInteger frameT))
              `quot` (toInteger mmY * 100)
        dpiW = (toInteger deviceX * 254) `quot` (toInteger mmX * 10)
        dpiH = (toInteger deviceY * 254) `quot` (toInteger mmY * 10)
      return $ ImageSize
        { pxX = w
        , pxY = h
        , dpiX = dpiW
        , dpiY = dpiH
        }
  in
    case parseheader . BL.fromStrict $ img of
      Left _ -> Nothing
      Right (_, _, size) -> Just size

-- See https://developers.google.com/speed/webp/docs/riff_container
-- and RFC 6386
pWebpSize :: AW.Parser ImageSize
pWebpSize = do
  AW.string "RIFF"
  AW.take 4
  AW.string "WEBP"
  (w, h) <- lossy <|> lossless <|> extended
  return $ def
    { pxX = w
    , pxY = h
    }
  where
    bitsToMaybe = either (const Nothing) (\((_, _, s)) -> Just s)
    decode d = bitsToMaybe . d . BL.fromStrict
    lossySize = runGetOrFail $ do
      word <- getWord16le
      return $ word .&. 0x3FFF
    lossy = do
      AW.string "VP8 "
      AW.take 4 -- length in bytes of VP8 Lossy stream size
      keyFrame <-  AW.anyWord8
      guard $ keyFrame .&. 1 == 0
      AW.take 2 -- remaining bytes of frame header
      AW.word8 0x9d  -- VP8 keyframe magic
      AW.word8 0x01
      AW.word8 0x2a
      width16 <- AW.take 2
      height16 <- AW.take 2
      case (decode lossySize width16, decode lossySize height16) of
        (Just w, Just h) -> return (toInteger w, toInteger h)
        _ -> empty
    -- The VP8L bitstream is read starting from the least significant
    -- bit of each byte, so after reading the 4 bytes as a little-endian
    -- word, width - 1 is in bits 0-13 and height - 1 in bits 14-27.
    losslessSizes = runGetOrFail getWord32le
    losslessSize word = 1 + (word .&. 0x3FFF)
    lossless = do
      AW.string "VP8L"
      AW.take 4 -- length in bytes of VP8 Lossless chunk size
      AW.word8 0x2f  -- webp lossless stream magic
      sizes <- AW.take 4
      case decode losslessSizes sizes of
        Just word -> return ( toInteger $ losslessSize word
                            , toInteger $ losslessSize (word `shiftR` 14) )
        Nothing -> empty
    extendedSize = runGetOrFail $ do
      low <- toInteger <$> getWord16le
      high <- toInteger <$> getWord8
      return $ 1 + (high `shiftL` 16) + (low)
    extended = do
      AW.string "VP8X"
      AW.take 8  -- VP8X chunk length, flags and reserved area
      width24 <- AW.take 3
      height24 <- AW.take 3
      case (decode extendedSize width24, decode extendedSize height24) of
        (Just w, Just h) -> return (w, h)
        _ -> empty

webpSize :: WriterOptions -> ByteString -> Maybe ImageSize
webpSize opts img =
  case AW.parseOnly pWebpSize img of
    Left _   -> Nothing
    Right sz -> Just sz { dpiX = fromIntegral $ writerDpi opts, dpiY = fromIntegral $ writerDpi opts}

avifSize :: WriterOptions -> ByteString -> Maybe ImageSize
avifSize opts img =
  case runGetOrFail (verifyFtyp >> findAvifDimensions) (BL.fromStrict img) of
    Left (_, _, _err) -> Nothing
    Right (_, _, (width, height)) ->
      Just $ ImageSize { pxX = fromIntegral width
                       , pxY = fromIntegral height
                       , dpiX = fromIntegral $ writerDpi opts
                       , dpiY = fromIntegral $ writerDpi opts }

---- AVIF parsing:

-- | Read an ISO BMFF box header, returning the box type, the size of
-- the box contents, and the size of the header itself.  Handles the
-- 64-bit "largesize" field (size == 1) and boxes that extend to the
-- end of the file (size == 0).
getBoxHeader :: Get (B.ByteString, Int, Int)
getBoxHeader = do
  boxSize <- getWord32be
  boxType <- getByteString 4
  case boxSize of
    0 -> do  -- the box extends to the end of the file
      rest <- lookAhead getRemainingLazyByteString
      return (boxType, fromIntegral (BL.length rest), 8)
    1 -> do  -- a 64-bit size follows the box type
      largeSize <- getWord64be
      when (largeSize < 16 || largeSize > 0x7fffffff) $
        fail "invalid box largesize"
      return (boxType, fromIntegral largeSize - 16, 16)
    _ -> do
      when (boxSize < 8) $ fail "invalid box size"
      return (boxType, fromIntegral boxSize - 8, 8)

verifyFtyp :: Get ()
verifyFtyp = do
  (boxType, contentSize, _) <- getBoxHeader
  unless (boxType == "ftyp") $ fail "ftyp signature not found"
  when (contentSize < 8) $ fail "Invalid ftyp size"

  brand <- getByteString 4
  unless (brand == "avif" || brand == "avis") $ fail "Not an AVIF file"

  -- Skip minor version and compatible brands
  skip (contentSize - 4)

findAvifDimensions :: Get (Word32, Word32)
findAvifDimensions = searchAvifBoxes []

searchAvifBoxes :: [B.ByteString] -> Get (Word32, Word32)
searchAvifBoxes path = do
  isempty <- isEmpty
  if isempty
    then fail $ "No dimensions found. Searched: " ++ show (reverse path)
    else do
      (boxType, contentSize, _) <- getBoxHeader
      let newPath = boxType : path

      -- If it's a container box, search inside it
      if isContainerBox boxType
        then searchInsideBox contentSize newPath
        else do
          -- Try to parse dimensions from this box
          result <- tryParseDimensions boxType contentSize
          case result of
            Just dims -> return dims
            Nothing ->
              -- Don't skip here - tryParseDimensions already handled it
              searchAvifBoxes path

tryParseDimensions :: B.ByteString -> Int -> Get (Maybe (Word32, Word32))
tryParseDimensions boxType size = do
  pos <- bytesRead
  result <- case boxType of
    "ispe" -> parseIspeBox
    "tkhd" -> parseTkhdBox
    "stsd" -> parseStsdBox
    "av01" -> parseAv01Box
    _ -> return Nothing

  -- Reset position if we didn't find dimensions
  case result of
    Nothing -> do
      newPos <- bytesRead
      let consumed = fromIntegral (newPos - pos)
      case size - consumed of
        n | n > 0 -> skip n
        _ -> return ()
    Just _ -> return ()

  return result

parseIspeBox :: Get (Maybe (Word32, Word32))
parseIspeBox = do
  skip 4  -- version/flags
  width <- getWord32be
  height <- getWord32be
  return $ Just (width, height)

parseTkhdBox :: Get (Maybe (Word32, Word32))
parseTkhdBox = do
  version <- getWord8
  skip 3  -- flags

  -- Skip to width/height based on version:
  -- creation/modification times, track ID, reserved, duration
  -- (20 bytes with 32-bit times, 32 bytes with 64-bit times),
  -- then 8 reserved, layer, alternate_group, volume, reserved
  -- (2 bytes each), and the 36-byte transformation matrix
  let skipBytes = if version == 1 then 84 else 72
  skip skipBytes

  width <- getWord32be
  height <- getWord32be
  -- Convert from 16.16 fixed point
  return $ Just (width `shiftR` 16, height `shiftR` 16)

parseStsdBox :: Get (Maybe (Word32, Word32))
parseStsdBox = do
  skip 8  -- version, flags, entry count
  findAv01Entry

findAv01Entry :: Get (Maybe (Word32, Word32))
findAv01Entry = do
  entrySize <- getWord32be
  codec <- getByteString 4

  if codec == "av01"
    then do
      skip 6  -- reserved
      skip 2  -- data reference index
      skip 16 -- pre-defined + reserved
      width <- getWord16be
      height <- getWord16be
      return $ Just (fromIntegral width, fromIntegral height)
    else do
      let skipSize = fromIntegral entrySize - 8
      when (skipSize > 0) $ skip skipSize
      findAv01Entry

parseAv01Box :: Get (Maybe (Word32, Word32))
parseAv01Box = do
  skip 6   -- reserved
  skip 2   -- data reference index
  skip 16  -- predefined/reserved
  width <- getWord16be
  height <- getWord16be
  return $ Just (fromIntegral width, fromIntegral height)

searchInsideBox :: Int -> [B.ByteString] -> Get (Word32, Word32)
searchInsideBox size path = do
  -- For meta boxes, skip version/flags
  let isMeta = case path of
                 "meta":_ -> True
                 _ -> False
  when isMeta $ skip 4

  let searchSize = if isMeta then size - 4 else size
  searchAvifBoxesInRange searchSize path

searchAvifBoxesInRange :: Int -> [B.ByteString] -> Get (Word32, Word32)
searchAvifBoxesInRange remaining' path
  | remaining' < 8 = searchAvifBoxes path
  | otherwise = do
      (boxType, contentSize, headerSize) <- getBoxHeader

      let newPath = boxType : path

      when (contentSize + headerSize > remaining') $
        fail $ "Malformed box at path: " ++ show (reverse newPath)

      if isContainerBox boxType
        then searchInsideBox contentSize newPath
        else do
          result <- tryParseDimensions boxType contentSize
          case result of
            Just dims -> return dims
            Nothing -> do
              -- Don't skip here - tryParseDimensions already handled it
              searchAvifBoxesInRange
                (remaining' - contentSize - headerSize) path

isContainerBox :: B.ByteString -> Bool
isContainerBox boxType = boxType `elem`
  ["moov", "trak", "mdia", "minf", "stbl", "meta", "dinf", "ipco", "iprp"]
