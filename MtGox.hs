{-# LANGUAGE OverloadedStrings #-}

import Network.HTTP
import Data.Map
import Data.Aeson hiding (Success, Error, Value)
import Data.Aeson.Types (Parser)
import Control.Applicative
import Control.Monad
import Data.Text (Text)
import Data.ByteString.Lazy.Char8 hiding (putStrLn)
import Data.HashMap.Strict hiding ((!))
import Data.List
import Data.Int (Int64)

tickerAPIURL :: Currency -> String
tickerAPIURL c = "http://data.mtgox.com/api/2/BTC" ++ (show c) ++ "/money/ticker"

data Currency = BTC
              | USD 
              | AUD
              deriving (Show, Read)

data Value = Value Currency Int64 deriving Show

data TickerAPIResponse = Success { payload :: TickerAPIPayload }
                       | Error   { error :: String }
                       deriving Show

data TickerAPIPayload = Payload {
                              item :: String
                            , now  :: String
                            , info :: Map String TickerInfo } deriving Show

data TickerInfo = TickerInfo {
                      value         :: Value
                    , display       :: String
                    , displayShort  :: String } | Failed deriving Show


instance FromJSON TickerAPIResponse where
  parseJSON (Object v) = do result <- v.: "result"
                            case result :: String of
                              "success" -> Success <$> v.: "data"
                              "error"   -> Error   <$> v.: "error"
  parseJSON _          = mzero

instance FromJSON TickerAPIPayload where
  parseJSON (Object v) = Payload          <$>
                         v .: "item"      <*>
                         v .: "now"       <*>
                         (parseJSON $ Object $ Data.HashMap.Strict.filterWithKey
                                      (\k _ -> Data.List.notElem k ["item", "now"])
                                      v)
  parseJSON _          = mzero

instance FromJSON TickerInfo where
  parseJSON (Object v) = TickerInfo <$>
                            (Value <$> (v .:~ "currency") <*> (v .:~ "value_int")) <*>
                            v .: "display"                                         <*>
                            v .: "display_short"
  parseJSON _          = return Failed

convert :: Read a => Parser String -> Parser a
convert = liftM read

(.:~) :: Read a => Object -> Text -> Parser a
(.:~) o k = convert (o .: k)

parseJsonBody :: String -> Either String TickerAPIResponse
parseJsonBody s = eitherDecode $ pack s

processPayload :: TickerAPIPayload -> IO ()
processPayload  p = putStrLn $ show $ (info p) ! "last"

tickerAPIRequest :: Currency -> IO TickerAPIResponse
tickerAPIRequest c = do result <- simpleHTTP (getRequest $ tickerAPIURL c)
                        case result of
                          (Left err)       -> return $ Error $ show err
                          (Right _)        -> handleResponse result
                     where handleResponse result = do body <- getResponseBody result
                                                      case (parseJsonBody body) of
                                                        (Left err)          -> return $ Error err
                                                        (Right apiResponse) -> return apiResponse

extractLast :: TickerAPIResponse -> String
extractLast (Success (Payload _ _ info)) = displayShort $ info ! "last"
extractLast (Error payload)   = "-"

main :: IO ()
main = do responses <- mapM tickerAPIRequest [USD, AUD]
          putStrLn $ Data.List.intercalate " " . Data.List.map extractLast $ responses

