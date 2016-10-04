module Rattletrap.ClassAttributeMap where

import Rattletrap.ActorMap
import Rattletrap.AttributeMapping
import Rattletrap.Cache
import Rattletrap.ClassMapping
import Rattletrap.CompressedWord
import Rattletrap.Data
import Rattletrap.List
import Rattletrap.Text
import Rattletrap.Utility
import Rattletrap.Word32

import qualified Data.Bimap as Bimap
import qualified Data.List as List
import qualified Data.Map as Map
import qualified Data.Maybe as Maybe
import qualified Data.Set as Set

data ClassAttributeMap = ClassAttributeMap
  { classAttributeMapObjectMap :: Bimap.Bimap Word32 Text
  , classAttributeMapClassMap :: Bimap.Bimap Word32 Text
  , classAttributeMapValue :: Map.Map Word32 (Bimap.Bimap Word32 Text)
  } deriving (Eq, Show)

makeClassAttributeMap :: List Text
                      -> List ClassMapping
                      -> List Cache
                      -> ClassAttributeMap
makeClassAttributeMap objects classMappings _ =
  ClassAttributeMap
  { classAttributeMapObjectMap = makeObjectMap objects
  , classAttributeMapClassMap = makeClassMap classMappings
  , classAttributeMapValue = error "CAM value"
  }

makeClassCache :: List ClassMapping
               -> List Cache
               -> [(Maybe Text, Word32, Word32, Word32)]
makeClassCache classMappings caches =
  let classMap = makeClassMap classMappings
  in map
       (\cache ->
          let classId = cacheClassId cache
          in ( Bimap.lookup classId classMap
             , classId
             , cacheCacheId cache
             , cacheParentCacheId cache))
       (listValue caches)

makeClassMap :: List ClassMapping -> Bimap.Bimap Word32 Text
makeClassMap classMappings =
  Bimap.fromList
    (map
       (\classMapping ->
          (classMappingStreamId classMapping, classMappingName classMapping))
       (listValue classMappings))

makeAttributeMap :: List Cache -> Map.Map Word32 (Bimap.Bimap Word32 Word32)
makeAttributeMap caches =
  Map.fromList
    (map
       (\cache ->
          ( cacheClassId cache
          , Bimap.fromList
              (map
                 (\attributeMapping ->
                    ( attributeMappingStreamId attributeMapping
                    , attributeMappingObjectId attributeMapping))
                 (listValue (cacheAttributeMappings cache)))))
       (listValue caches))

makeShallowParentMap :: List ClassMapping -> List Cache -> Map.Map Word32 Word32
makeShallowParentMap classMappings caches =
  let classCache = makeClassCache classMappings caches
  in Map.fromList
       (Maybe.mapMaybe
          (\xs ->
             case xs of
               [] -> Nothing
               (maybeClassName, classId, _, parentCacheId):rest -> do
                 parentClassId <-
                   getParentClass maybeClassName parentCacheId rest
                 pure (classId, parentClassId))
          (List.tails (reverse classCache)))

makeParentMap :: List ClassMapping -> List Cache -> Map.Map Word32 [Word32]
makeParentMap classMappings caches =
  let shallowParentMap = makeShallowParentMap classMappings caches
  in Map.map (getParentClasses shallowParentMap) shallowParentMap

getParentClasses :: Map.Map Word32 Word32 -> Word32 -> [Word32]
getParentClasses shallowParentMap classId =
  case Map.lookup classId shallowParentMap of
    Nothing -> []
    Just parentClassId ->
      parentClassId : getParentClasses shallowParentMap parentClassId

getParentClass :: Maybe Text
               -> Word32
               -> [(Maybe Text, Word32, Word32, Word32)]
               -> Maybe Word32
getParentClass maybeClassName parentCacheId xs =
  case maybeClassName of
    Nothing -> getParentClassById parentCacheId xs
    Just className -> getParentClassByName className parentCacheId xs

getParentClassById :: Word32
                   -> [(Maybe Text, Word32, Word32, Word32)]
                   -> Maybe Word32
getParentClassById parentCacheId xs =
  case dropWhile (\(_, _, cacheId, _) -> cacheId /= parentCacheId) xs of
    [] ->
      if parentCacheId == Word32 0
        then Nothing
        else getParentClassById (Word32 (word32Value parentCacheId - 1)) xs
    (_, parentClassId, _, _):_ -> Just parentClassId

getParentClassByName :: Text
                     -> Word32
                     -> [(Maybe Text, Word32, Word32, Word32)]
                     -> Maybe Word32
getParentClassByName className parentCacheId xs =
  case Map.lookup className parentClasses of
    Nothing -> getParentClassById parentCacheId xs
    Just parentClassName ->
      Maybe.maybe
        (getParentClassById parentCacheId xs)
        Just
        (Maybe.listToMaybe
           (map
              (\(_, parentClassId, _, _) -> parentClassId)
              (filter
                 (\(_, _, cacheId, _) -> cacheId == parentCacheId)
                 (filter
                    (\(maybeClassName, _, _, _) ->
                       maybeClassName == Just parentClassName)
                    xs))))

parentClasses :: Map.Map Text Text
parentClasses =
  Map.map
    stringToText
    (Map.mapKeys stringToText (Map.fromList rawParentClasses))

makeObjectMap :: List Text -> Bimap.Bimap Word32 Text
makeObjectMap objects =
  Bimap.fromList (zip (map Word32 [0 ..]) (listValue objects))

getObjectName :: ClassAttributeMap -> Word32 -> Maybe Text
getObjectName classAttributeMap objectId =
  Bimap.lookup objectId (classAttributeMapObjectMap classAttributeMap)

getClassName :: Text -> Maybe Text
getClassName rawObjectName =
  Map.lookup (normalizeObjectName rawObjectName) objectClasses

normalizeObjectName :: Text -> Text
normalizeObjectName objectName =
  stringToText
    (replace
       "_[0-9]+$"
       ""
       (replace "^[A-Z_a-z]+[.]TheWorld:" "TheWorld:" (textToString objectName)))

objectClasses :: Map.Map Text Text
objectClasses =
  Map.map
    stringToText
    (Map.mapKeys stringToText (Map.fromList rawObjectClasses))

classHasLocation :: Text -> Bool
classHasLocation className = Set.member className classesWithLocation

classesWithLocation :: Set.Set Text
classesWithLocation = Set.fromList (map stringToText rawClassesWithLocation)

classHasRotation :: Text -> Bool
classHasRotation className = Set.member className classesWithRotation

classesWithRotation :: Set.Set Text
classesWithRotation = Set.fromList (map stringToText rawClassesWithRotation)

getAttributeIdLimit :: ClassAttributeMap
                    -> ActorMap
                    -> CompressedWord
                    -> Maybe Word
getAttributeIdLimit _classAttributeMap _actorMap _actorId = Nothing -- TODO

getAttributeName :: ClassAttributeMap
                 -> CompressedWord
                 -> CompressedWord
                 -> Maybe Text
getAttributeName _classAttributeMap _actorId _attributeId = Nothing -- TODO