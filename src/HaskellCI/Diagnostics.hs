module HaskellCI.Diagnostics where

import HaskellCI.Prelude

import Control.Monad.Trans.Maybe (MaybeT (..))
import Control.Monad.Writer      (WriterT, runWriterT, tell)
import System.Exit               (exitFailure)
import System.IO                 (hPutStrLn, stderr)

class Monad m => MonadDiagnostics m where
    putStrLnErr  :: String -> m a
    putStrLnErrs :: NonEmpty String -> m a
    putStrLnWarn :: String -> m ()
    putStrLnInfo :: String -> m ()

instance MonadDiagnostics IO where
    putStrLnErr err = do
        hPutStrLn stderr $ "*ERROR* " ++ err
        exitFailure

    putStrLnErrs errs = do
        for_ errs $ \err -> hPutStrLn stderr $ "*ERROR* " ++ err
        exitFailure

    putStrLnWarn = hPutStrLn stderr . ("*WARNING* " ++)
    putStrLnInfo = hPutStrLn stderr . ("*INFO* " ++)

newtype DiagnosticsT m a = Diagnostics { unDiagnostics :: MaybeT (WriterT [String] m) a }
  deriving stock (Functor)
  deriving newtype (Applicative, Monad, MonadIO, MonadCatch, MonadMask, MonadThrow)

runDiagnosticsT :: DiagnosticsT m a -> m (Maybe a, [String])
runDiagnosticsT (Diagnostics m) = runWriterT (runMaybeT m)

instance Monad m => MonadDiagnostics (DiagnosticsT m) where
    putStrLnWarn err = Diagnostics $ tell ["*WARNING* " ++ err]
    putStrLnInfo err = Diagnostics $ tell ["*INFO* " ++ err]

    putStrLnErr err = Diagnostics $ do
        tell ["*ERROR* " ++ err]
        MaybeT $ return Nothing

    putStrLnErrs errs = Diagnostics $ do
        tell $ map ("*ERROR* " ++) (toList errs)
        MaybeT $ return Nothing
