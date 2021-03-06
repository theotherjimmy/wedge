module Type where

import Rule
import Lex
import Control.Applicative
import Data.List

-- Type definitions
data Type
    = Void
    | Type String
    | StructType [Type]
    | ArrayType Type Int
    | FuncType Type Type
    deriving Show


-- Type rules
base :: Rule Token Type
base = Rule $ \ts -> case ts of
    Sym{tsym="void"}:ts -> Accept Void ts
    Sym{tsym=sym}:ts    -> Accept (Type sym) ts
    Token{tt="("}:ts    -> step (type_ <* token ")") ts
    ts                  -> Reject ts

struct :: Rule Token Type
struct = toStruct <$> delimited1 base (token ",")
  where
    toStruct [y] = y
    toStruct ys  = StructType ys

type_ :: Rule Token Type
type_ = func <|> array <|> struct
  where
    func  = FuncType  <$> struct <* token "(" <*> struct <* token ")"
    array = ArrayType <$> struct <* token "[" <*> int    <* token "]"

-- TODO fold this into another function?
funcVar :: Rule Token (Type, String)
funcVar = toFunc <$> type_ <*> sym <* token "(" <*> type_ <* token ")"
  where toFunc ret name arg = (FuncType ret arg, name)

var :: Rule Token (Type, String)
var = func <|> array <|> ((,) <$> type_ <*> sym)
  where
    func  = toFunc  <$> type_ <*> sym <* token "(" <*> type_ <* token ")"
    array = toArray <$> type_ <*> sym <* token "[" <*> int   <* token "]"
    toFunc  ret name arg   = (FuncType ret arg, name)
    toArray ret name count = (ArrayType ret count, name)


-- Emitting definitions
emitArgs :: Type -> String
emitArgs y = (\s -> "(" ++ s ++ ")") $ case y of
    StructType ys -> intercalate ", " $ map emitType ys
    y             -> emitType y

emitMembers :: Type -> String
emitMembers (StructType ys) =
    (\s -> "{" ++ s ++ "}") $ intercalate " " $ map ((++";") . emitType) ys

emitType :: Type -> String
emitType y = case y of
    Void          -> "void"
    Type "int"    -> "int"
    Type "uint"   -> "unsigned"
    Type "float"  -> "float"
    Type t        -> t
    StructType _  -> "struct " ++ emitMembers y
    ArrayType y n -> emitType y ++ "[" ++ show n ++ "]"
    FuncType y z  -> emitType y ++ " (*)" ++ emitArgs z

emitTypeDecl :: Type -> String -> String
emitTypeDecl y name = case y of
    ArrayType y n -> emitType y ++ " " ++ name ++ "[" ++ show n ++ "]"
    FuncType y z  -> emitType y ++ " (*" ++ name ++ ")" ++ emitArgs z
    y             -> emitType y ++ " " ++ name

