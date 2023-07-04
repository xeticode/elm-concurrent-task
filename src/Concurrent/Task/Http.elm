module Concurrent.Task.Http exposing
    ( Request, request
    , Expect, expectJson, expectString, expectWhatever
    , Error(..), StatusDetails
    , Header, header
    , Body, emptyBody, jsonBody
    )

{-| Make concurrent http requests


# Request

@docs Request, request


# Expect

@docs Expect, expectJson, expectString, expectWhatever


# Error

@docs Error, StatusDetails


# Header

@docs Header, header


# Body

@docs Body, emptyBody, jsonBody

-}

import Concurrent.Task as Task exposing (Task)
import Internal.Task as Internal
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode



-- Http Task


{-| -}
type alias Request a =
    { url : String
    , method : String
    , headers : List Header
    , body : Body
    , expect : Expect a
    }


{-| -}
type Body
    = Json Encode.Value


{-| -}
type Expect a
    = ExpectJson (Decoder a)
    | ExpectString (Decoder a)


{-| -}
type alias Header =
    ( String, String )


{-| -}
type Error
    = BadUrl String
    | Timeout
    | NetworkError
    | BadStatus StatusDetails
    | BadBody String
    | TaskError Task.Error


{-| -}
type alias StatusDetails =
    { code : Int
    , text : String
    , body : Decode.Value
    }



-- Header


{-| -}
header : String -> String -> Header
header =
    Tuple.pair



-- Expect


{-| -}
expectJson : Decoder a -> Expect a
expectJson =
    ExpectJson


{-| -}
expectString : Expect String
expectString =
    ExpectString Decode.string


{-| -}
expectWhatever : Expect ()
expectWhatever =
    ExpectJson (Decode.succeed ())



-- Body


{-| -}
emptyBody : Body
emptyBody =
    Json Encode.null


{-| -}
jsonBody : Encode.Value -> Body
jsonBody =
    Json



-- Send Request


{-| -}
request : Request a -> Task Error a
request r =
    Task.define
        { function = "builtin:http"
        , args = encode r
        , expect = Task.expectJson (decodeResponse r)
        }
        |> Task.mapError wrapError
        |> Task.andThen Task.fromResult


wrapError : Task.Error -> Error
wrapError err =
    case err of
        Internal.DecodeResponseError e ->
            BadBody (Decode.errorToString e)

        _ ->
            TaskError err


decodeResponse : Request a -> Decoder (Result Error a)
decodeResponse r =
    Decode.oneOf
        [ decodeExpect r.expect
        , decodeError r
        ]


decodeError : Request a -> Decoder (Result Error value)
decodeError r =
    Decode.field "error" Decode.string
        |> Decode.andThen
            (\code ->
                case code of
                    "TIMEOUT" ->
                        Decode.succeed (Err Timeout)

                    "NETWORK_ERROR" ->
                        Decode.succeed (Err NetworkError)

                    "BAD_URL" ->
                        Decode.succeed (Err (BadUrl r.url))

                    "BAD_BODY" ->
                        Decode.field "body" Decode.string
                            |> Decode.map (Err << BadBody)

                    _ ->
                        Decode.succeed (Err (TaskError (Internal.InternalError ("Unknown error code: " ++ code))))
            )


decodeExpect : Expect a -> Decoder (Result Error a)
decodeExpect expect =
    Decode.field "status" Decode.int
        |> Decode.andThen
            (\code ->
                if code >= 200 && code < 300 then
                    case expect of
                        ExpectJson decoder ->
                            Decode.field "body" (Decode.map Ok decoder)

                        ExpectString decoder ->
                            Decode.field "body" (Decode.map Ok decoder)

                else
                    Decode.map2
                        (\text body ->
                            Err
                                (BadStatus
                                    { code = code
                                    , text = text
                                    , body = body
                                    }
                                )
                        )
                        (Decode.field "statusText" Decode.string)
                        (Decode.field "body" Decode.value)
            )



-- Encode Request


encode : Request a -> Encode.Value
encode r =
    Encode.object
        [ ( "url", Encode.string r.url )
        , ( "method", Encode.string r.method )
        , ( "headers", Encode.list encodeHeader r.headers )
        , ( "expect", encodeExpect r.expect )
        , ( "body", encodeBody r.body )
        ]


encodeExpect : Expect a -> Encode.Value
encodeExpect expect =
    case expect of
        ExpectString _ ->
            Encode.string "STRING"

        ExpectJson _ ->
            Encode.string "JSON"


encodeHeader : Header -> Encode.Value
encodeHeader ( name, value ) =
    Encode.object
        [ ( "name", Encode.string name )
        , ( "value", Encode.string value )
        ]


encodeBody : Body -> Encode.Value
encodeBody body =
    case body of
        Json value ->
            value