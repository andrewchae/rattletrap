module Rattletrap.ReplicationValue where

import Rattletrap.Attribute
import Rattletrap.CompressedWord
import Rattletrap.Initialization
import Rattletrap.Word32

import qualified Data.Binary.Bits.Get as BinaryBit
import qualified Data.Binary.Bits.Put as BinaryBit

data ReplicationValue
  = SpawnedReplication Bool
                       Word32
                       Initialization
  | UpdatedReplication [Attribute]
  | DestroyedReplication
  deriving (Eq, Ord, Show)

getReplicationValue :: BinaryBit.BitGet ReplicationValue
getReplicationValue = do
  let getClassName :: Word32 -> String
      getClassName _objectId = error "get class name"
      classHasLocation :: String -> Bool
      classHasLocation _className = error "class has location"
      classHasRotation :: String -> Bool
      classHasRotation _className = error "class has rotation"
      attributeIdLimit :: Word
      attributeIdLimit = error "attribute id limit"
      getAttributeName :: CompressedWord -> String
      getAttributeName _id = error "get attribute name"
  isOpen <- BinaryBit.getBool
  if isOpen
    then do
      isNew <- BinaryBit.getBool
      if isNew
        then do
          unknown <- BinaryBit.getBool
          objectId <- getWord32Bits
          let className = getClassName objectId
          let hasLocation = classHasLocation className
          let hasRotation = classHasRotation className
          initialization <- getInitialization hasLocation hasRotation
          pure (SpawnedReplication unknown objectId initialization)
        else do
          attributes <- getAttributes attributeIdLimit getAttributeName
          pure (UpdatedReplication attributes)
    else pure DestroyedReplication

putReplicationValue :: ReplicationValue -> BinaryBit.BitPut ()
putReplicationValue value =
  case value of
    SpawnedReplication unknown objectId initialization -> do
      BinaryBit.putBool True
      BinaryBit.putBool True
      BinaryBit.putBool unknown
      putWord32Bits objectId
      putInitialization initialization
    UpdatedReplication attributes -> do
      BinaryBit.putBool True
      BinaryBit.putBool False
      putAttributes attributes
    DestroyedReplication -> BinaryBit.putBool False