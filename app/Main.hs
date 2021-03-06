{-# LANGUAGE CPP #-}
{-# LANGUAGE QuasiQuotes #-}

module Main where

import Control.Monad (when)
import Data.Maybe (fromJust)
import Helper (compileResult)
import Nuri.Parse.Stmt (parseInput)
import System.Console.Docopt
  ( Arguments,
    Docopt,
    argument,
    docoptFile,
    getArg,
    getArgWithDefault,
    isPresent,
    longOption,
    parseArgs,
  )
import System.Directory (doesFileExist)
import System.Environment (getArgs)
import System.FilePath (replaceExtension)
import System.Process (callCommand)

patterns :: Docopt
patterns = [docoptFile|USAGE.txt|]

runCommand :: Arguments -> IO ()
runCommand opts = do
  when (opts `isPresent` (longOption "help")) $ do
    putTextLn helpMessage
    exitSuccess
  when (opts `isPresent` (longOption "version")) $ do
    putStrLn "누리 0.1.0"
    exitSuccess
  when (opts `isPresent` (argument "file")) $ do
#ifdef mingw32_HOST_OS
    let defaultHaneul = ".\\haneul.exe"
#else
    let defaultHaneul = "./haneul"
#endif

    let filePath = fromJust $ opts `getArg` (argument "file")
        isDebug = opts `isPresent` (longOption "debug")
        haneulPath = getArgWithDefault opts defaultHaneul (longOption "haneul")

    exists <- doesFileExist filePath
    when (not exists) $ do
      putStrLn $ "오류 : '" ++ filePath ++ "' 파일을 찾을 수 없습니다."
      exitFailure

    content <- readFileText filePath
    result <- parseInput content filePath

    let bytecodeFileName = replaceExtension filePath ".hn"
    compileResult filePath isDebug bytecodeFileName result
    callCommand $ haneulPath ++ " '" ++ bytecodeFileName ++ "'"

helpMessage :: Text
helpMessage =
  unlines
    [ "누리 - 함수형 한글 프로그래밍 언어 0.1.0",
      "",
      "사용법:",
      "  nuri --help | -h",
      "  nuri --version | -v",
      "  nuri <파일명> [--debug | -d] [--haneul=<path>]",
      "",
      "옵션:",
      "  -h, --help        도움말을 출력합니다.",
      "  -v, --version     누리 실행기의 버전을 출력합니다.",
      "  -d, --debug       디버그용 출력을 활성화합니다.",
      "  --haneul=<path>   하늘 가상머신 실행 파일의 경로를 설정합니다.",
      "                    [기본 : 같은 경로의 haneul 파일]"
    ]

main :: IO ()
main = do
  args <- getArgs
  let result = parseArgs patterns args

  case result of
    Left _ -> do
      putTextLn helpMessage
      exitFailure
    Right opts -> runCommand opts
