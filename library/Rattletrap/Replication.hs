module Rattletrap.Replication where

import Rattletrap.CompressedWord
import Rattletrap.ReplicationValue

import qualified Data.Binary.Bits.Get as BinaryBit
import qualified Data.Binary.Bits.Put as BinaryBit

data Replication = Replication
  { replicationActorId :: CompressedWord
  , replicationValue :: ReplicationValue
  } deriving (Eq, Ord, Show)

getReplications :: BinaryBit.BitGet [Replication]
getReplications = do
  maybeReplication <- getReplication
  case maybeReplication of
    Nothing -> pure []
    Just replication -> do
      replications <- getReplications
      pure (replication : replications)

putReplications :: [Replication] -> BinaryBit.BitPut ()
putReplications replications = do
  mapM_ putReplication replications
  BinaryBit.putBool False

getReplication :: BinaryBit.BitGet (Maybe Replication)
getReplication = do
  hasReplication <- BinaryBit.getBool
  if not hasReplication
    then pure Nothing
    else do
      actorId <- getCompressedWord maxActorId
      value <- getReplicationValue
      pure
        (Just
           Replication {replicationActorId = actorId, replicationValue = value})

putReplication :: Replication -> BinaryBit.BitPut ()
putReplication replication = do
  BinaryBit.putBool True
  putCompressedWord (replicationActorId replication)
  putReplicationValue (replicationValue replication)

maxActorId :: Word
maxActorId = 1023