import Prelude hiding (readFile)
import Data.ByteString.Lazy (readFile)
import Data.Text (pack)
import Data.Text.Lazy (strip, unpack)
import Data.Text.Lazy.Encoding (decodeUtf8)
import Data.Aeson (FromJSON, Value(..), parseJSON, (.:), decode)
import Control.Applicative ((<$>), (<*>))
import Control.Monad (mzero)
import Data.List (find)
import System.FilePath.Posix (combine, splitFileName)
import System.Directory (getDirectoryContents)
import Data.List.Split (splitOn, splitOneOf)
import System.Process (createProcess, proc, waitForProcess, readProcessWithExitCode)
import System.Exit (ExitCode(..))
import System.Posix.Files (setFileMode, fileMode, getFileStatus)
import System.INotify (initINotify, addWatch, Event(..), EventVariety(..), removeWatch)
import System.Environment (getArgs)

cpCommandPath = "/bin/cp"

-- | The configuration for each binary to be monitored.
data Item = Item {
    binaryFileName :: String,
    targetFolder :: String,
    pidFile :: String
} deriving (Show)

-- | The top-level configuration item, which contains a folder to monitor and a list of items to watch for.
data Configuration = Configuration {
    incomingFolder :: String,
    watchItems :: [Item]
} deriving (Show)

-- | Data.Aeson required decode function to parse for an Item.
-- Here is an example:
-- {
--      "binaryFileName": "rate",
--      "targetFolder": "/home/zhu/yesod-app",
--      "pidFile": "/home/zhu/yesod-app/app.pid"
-- }
instance FromJSON Item where
    parseJSON (Object o) = Item <$>
                            o .: pack "binaryFileName" <*>
                            o .: pack "targetFolder" <*>
                            o .: pack "pidFile"
    parseJSON _ = mzero

-- | Data.Aeson required decode function to parse for the top-level configuration.
-- An example of complete configuration:
-- {
--    "incomingFolder": "/home/zhu/app-incoming",
--    "watchItems":
--    [
--        {
--            "binaryFileName": "rate",
--            "targetFolder": "/home/zhu/yesod-app",
--            "pidFile": "/home/zhu/yesod-app/app.pid"
--        }
--    ]
-- }
instance FromJSON Configuration where
    parseJSON (Object o) = Configuration <$>
                            o .: pack "incomingFolder" <*>
                            o .: pack "watchItems"
    parseJSON _ = mzero

-- | Use INotify to monitor uploading folder.  When a new or modified file was detected, it will call fileUpdated.
watchForUpdatedFiles :: Configuration -> IO ()
watchForUpdatedFiles config = do
    inotify <- initINotify
    wd <- addWatch
        inotify
        [Close]
        (incomingFolder config)
        (fileUpdated config)
    putStrLn $ "Watching incoming folder [" ++ incomingFolder config ++ "]. Hit enter to terminate."
    _ <- getLine
    removeWatch wd

-- | This function will be called whenever a file was updated in the upcoming folder.  If the file updated matches a watch item's binary file name, the following will happen:
--      (1), the updated file will be copied to the watch item's target folder and set to executable;
--      (2), all the watch item's current running process(es) will be killed. 
fileUpdated :: Configuration -> Event -> IO ()
fileUpdated Configuration { incomingFolder=incomingDir, watchItems=items } Closed { isDirectory = False, maybeFilePath = Just path, wasWriteable = True} = do
    putStrLn "****************File Change Detected****************"
    let i' = find (\Item { binaryFileName = p} -> p == path) items
    case i' of 
        Just Item { binaryFileName = bFileNameOnly, targetFolder = tFolder, pidFile = pFile} -> do
            putStrLn $ "Changes to [" ++ bFileNameOnly ++ "] was detected."
            let sourceFilePath = combine incomingDir bFileNameOnly
                targetFilePath = combine tFolder bFileNameOnly

            --get the original file mode
            status <- getFileStatus targetFilePath
            let mode = fileMode status
            
            (copyCode, stdoutString, stderrString) <- readProcessWithExitCode cpCommandPath [sourceFilePath, targetFilePath] ""
            case copyCode of
                ExitSuccess -> do
                    putStrLn $ "Copied from [" ++ sourceFilePath ++ "] to [" ++ targetFilePath ++ "]."
                    setFileMode targetFilePath mode
                    putStrLn $ "Restore file mode for [" ++ targetFilePath ++ "]."

                    pids <- getPIDs pFile
                    case length pids of
                        0 -> do
                            putStrLn "No PID was found.  Process is not running?"
                        _ -> do
                            putStrLn $ "Process IDs to be killed: " ++ show pids
                            let args = "-9" : pids
                            (_,_,_,handle) <- createProcess $ proc "kill" args
                            exitCode <- waitForProcess handle
                            case exitCode of
                                ExitSuccess -> do
                                    putStrLn $ "Process(es) killed!"
                                ExitFailure c -> do
                                    putStrLn $ "Cannot kill one or more processes, exit code:" ++ show c ++ "."
                ExitFailure n -> do
                    putStrLn $ "Cannot copy from [" ++ sourceFilePath ++ "] to [" ++ targetFilePath ++ "]."
                    putStrLn $ "/bin/cp exit code: " ++ show n
                    putStrLn $ "           stdout: " ++ stdoutString
                    putStrLn $ "           stderr: " ++ stderrString
                    putStrLn $ "Cannot continue, target is NOT updated. NO process was killed!"
                
        -- The updated file in the upcoming folder is not related to any watch item
        Nothing -> return ()
fileUpdated _ _ = return ()

-- | Get one or more process IDs from a file.  Angel PID file name convention is used.
-- For example, give a process ID file "/home/zhu/yesod-app/app.pid", the following files will be checked:
--      /home/zhu/yesod-app/app.pid
--      /home/zhu/yesod-app/app-?.pid (where ? is a number)
getPIDs :: String -> IO [String]
getPIDs fileName = do
    let (dir, path) = splitFileName fileName
    files <- getDirectoryContents dir
    let pidFiles = map (combine dir) $ filter (isPIDFile path) files
    --print pidFiles
    pids' <- mapM readFile pidFiles
    let pids = map (unpack.strip.decodeUtf8) pids'
    return pids

-- | Is fileName a possible PID file based on Angel convention?
--  For example:
--      isPIDFile "app.pid" "app.pid"  => true
--      isPIDFile "app.pid" "app-1.pid" => true
--      isPIDFile "app.pid" "app-12.pid" => true
--      isPIDFile "app.pid" "anything-else.txt" => false
isPIDFile :: String -> String -> Bool
isPIDFile fileName pathCandi = 
    let [name, ext] = splitOn "." fileName
        parts = splitOneOf ".-" pathCandi
    in  case parts of
        [name1, ext1] -> name1 == name && ext1 == ext
        [name2, num, ext2] -> name2 == name && ext2 == ext && isInteger num
        _ -> False

isInteger :: String -> Bool
isInteger s = case reads s :: [(Integer, String)] of 
    [(_, "")] -> True
    _         -> False

-- | Read the configuration file into a Configuration object
getConfiguration :: String -> IO (Maybe Configuration)
getConfiguration configFileName = do
    putStrLn $ "Trying to load configuration from " ++ configFileName
    content <- readFile configFileName
    let r = decode content :: Maybe Configuration
    return r

-- | Load configuration and set up to watch upcoming folder based on the configuration.
-- Q1. How to run this program?
-- A1. This program is designed to work with screen.  To start it in a named but detached screen session:
--          screen -S devil -d -m ./devil configure.json
-- Q2. How to reconnect it with screen?
-- A2.      screen -S devil -r
-- Q3. How to detach from screen?
-- A3.      ctrl+a d
main :: IO ()
main = do
    args <- getArgs
    case length args of
        1 -> do
            config' <- getConfiguration $ head args
            case config' of
                Nothing ->
                    putStrLn "Invalid configure json file!"
                Just config -> do
                    print config
                    watchForUpdatedFiles config
        _ -> do
            putStrLn "Wrong number of argument."
            putStrLn "Usage: devil configure.json"
