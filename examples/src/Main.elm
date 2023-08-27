port module Main exposing (main)

import Concurrent.Task as Task exposing (Task)
import Concurrent.Task.Http as Http
import Concurrent.Task.Process
import Concurrent.Task.Random
import Concurrent.Task.Time
import Env
import Json.Decode as Decode
import Json.Encode as Encode
import Random
import Time



-- Program


main : Program Flags Model Msg
main =
    Platform.worker
        { init = init
        , update = update
        , subscriptions = subscriptions
        }



-- Model


type alias Flags =
    {}


type alias Model =
    { tasks : Task.Pool Msg Error String
    }


type Msg
    = OnFireMany Int
    | OnManualEnter String
    | OnProgress ( Task.Pool Msg Error String, Cmd Msg )
    | OnComplete String (Task.Response Error String)


type Error
    = HttpError Http.Error
    | EnvError Env.Error
    | TaskError String



-- Init


init : Flags -> ( Model, Cmd Msg )
init _ =
    ( { tasks = Task.pool }
    , Cmd.none
    )



-- Example Tasks


longChain : Task Http.Error String
longChain =
    Task.map3 join3
        (longRequest_ 100)
        (longRequest_ 100)
        (httpError
            |> Task.onError (\_ -> longRequest_ 100)
            |> Task.andThen (\_ -> longRequest_ 100)
        )
        |> Task.andThenDo (longRequest_ 100)
        |> Task.andThenDo (longRequest_ 100)
        |> Task.andThenDo (longRequest_ 100)
        |> Task.andThenDo httpError
        |> Task.onError (\_ -> httpError)
        |> Task.onError (\_ -> httpError)
        |> Task.onError (\_ -> httpError)
        |> Task.onError (\_ -> httpError)
        |> Task.onError (\_ -> httpError)
        |> Task.onError (\_ -> longRequest_ 100)
        |> Task.andThenDo (longRequest_ 100)
        |> Task.andThenDo (longRequest_ 100)
        |> Task.onError (\_ -> httpError)
        |> Task.onError (\_ -> httpError)
        |> Task.onError (\_ -> longRequest_ 1000)
        |> Task.andThenDo
            (httpError
                |> Task.onError (\_ -> httpError)
                |> Task.onError (\_ -> httpError)
                |> Task.onError (\_ -> longRequest_ 500)
                |> Task.andThenDo (longRequest_ 500)
            )
        |> Task.andThenDo (longRequest_ 300)


someChain : Task Http.Error String
someChain =
    Task.map2 join2
        (Task.map3 join3
            (httpError
                |> Task.onError (\_ -> httpError)
                |> Task.onError (\_ -> httpError)
                |> Task.onError (\_ -> longRequest_ 100)
                |> Task.onError (\_ -> longRequest_ 100)
            )
            (httpError |> Task.onError (\_ -> longRequest_ 100))
            (longRequest_ 100)
        )
        (Task.map3 join3
            (longRequest_ 100)
            (longRequest_ 100)
            (longRequest_ 100)
        )
        |> Task.andThenDo (longRequest_ 100)
        |> Task.andThenDo (longRequest_ 100)
        |> Task.andThenDo (longRequest_ 100)
        |> Task.andThenDo (longRequest_ 100)
        |> Task.andThenDo (longRequest_ 100)


badChain : Task Http.Error String
badChain =
    Task.map2 join2
        (longRequest_ 100)
        (longRequest_ 100)
        |> Task.andThenDo (longRequest_ 100)
        |> Task.andThenDo
            (httpError
                |> Task.onError (\_ -> httpError)
                |> Task.onError (\_ -> longRequest_ 100)
            )
        |> Task.andThenDo
            (httpError
                |> Task.onError (\_ -> httpError)
                |> Task.onError (\_ -> longRequest_ 100)
                |> Task.onError (\_ -> longRequest_ 100)
                |> Task.andThenDo (longRequest_ 100)
            )
        |> Task.andThenDo (longRequest_ 100)


badChain2 : Task Http.Error String
badChain2 =
    longRequest_ 100
        |> Task.andThenDo
            (httpError
                |> Task.onError
                    (\_ ->
                        httpError
                            |> Task.onError
                                (\_ ->
                                    httpError
                                        |> Task.onError
                                            (\_ ->
                                                longRequest_ 100
                                            )
                                )
                    )
            )
        |> Task.andThenDo (longRequest_ 100)
        |> Task.andThenDo (longRequest_ 100)


doFour : Task Http.Error String
doFour =
    Task.map4 join4
        (longRequest_ 100)
        (longRequest_ 100)
        (longRequest_ 100)
        (longRequest_ 100)
        |> andThenJoinWith
            (Task.map2 join2
                (longRequest_ 100)
                (longRequest_ 100)
            )


doFive : Task Http.Error String
doFive =
    Task.map5 join5
        (longRequest_ 100)
        (longRequest_ 80)
        (longRequest_ 20)
        (longRequest_ 30)
        (longRequest_ 42)
        |> andThenJoinWith
            (Task.map2 join2
                (longRequest_ 100)
                (longRequest_ 110)
            )


andThenJoinWith : Task x String -> Task x String -> Task x String
andThenJoinWith t2 t1 =
    t1 |> Task.andThen (\a -> Task.map (join2 a) t2)


batchAndSequence : Task Http.Error String
batchAndSequence =
    List.repeat 10
        (List.range 0 1000
            |> List.map (\i -> sleep 100 |> Task.map (always (String.fromInt i)))
            |> Task.batch
        )
        |> Task.sequence
        |> Task.map (List.concat >> String.join ",")


bigBatch : Task Http.Error String
bigBatch =
    timeExecution "bigBatch"
        (List.repeat 1000 (longRequest_ 1000)
            |> Task.batch
            |> Task.map String.concat
        )


badChain3 : Task Http.Error String
badChain3 =
    Task.map3 join3
        doThree
        doThree
        doThree
        |> Task.andThenDo
            (retry 100 httpError
                |> Task.onError (\_ -> longRequest_ 100)
            )
        |> Task.andThenDo (longRequest_ 100)
        |> Task.andThenDo (longRequest_ 100)
        |> Task.andThenDo (longRequest_ 100)


doThree2 : Task Http.Error String
doThree2 =
    Task.map3 join3
        (longRequest_ 100 |> andThenJoinWith (longRequest_ 100))
        (longRequest_ 100 |> andThenJoinWith (longRequest_ 100))
        (longRequest_ 100 |> andThenJoinWith (longRequest_ 100))


doThree : Task Http.Error String
doThree =
    Task.map3 join3
        (httpError
            |> Task.onError (\_ -> httpError)
            |> Task.onError (\_ -> httpError)
            |> Task.onError (\_ -> httpError)
            |> Task.onError (\_ -> longRequest_ 50)
        )
        (httpError
            |> Task.onError (\_ -> httpError)
            |> Task.onError (\_ -> httpError)
            |> Task.onError (\_ -> httpError)
            |> Task.onError (\_ -> httpError)
            |> Task.onError (\_ -> longRequest_ 100)
        )
        (httpError
            |> Task.onError (\_ -> httpError)
            |> Task.onError (\_ -> httpError)
            |> Task.onError (\_ -> longRequest_ 150)
        )



-- Update


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OnManualEnter id ->
            let
                ( tasks, cmd ) =
                    Task.attempt
                        { send = send
                        , pool = model.tasks
                        , onComplete = OnComplete id
                        }
                        (Task.mapError HttpError bigBatch)
            in
            ( { tasks = tasks }, cmd )

        OnFireMany id ->
            let
                ( tasks, cmd ) =
                    Task.attempt
                        { send = send
                        , pool = model.tasks
                        , onComplete = OnComplete (String.fromInt id)
                        }
                        (slowSequence id)
            in
            ( { tasks = tasks }, cmd )

        OnComplete id result ->
            ( model
            , sendResult ("result for " ++ id ++ ": " ++ Debug.toString result)
            )

        OnProgress ( task, cmd ) ->
            ( { model | tasks = task }, cmd )



-- Task


randomTask : Task x Int
randomTask =
    Concurrent.Task.Random.generate (Random.int 0 100000000)


timeNowTask : Task x Time.Posix
timeNowTask =
    Concurrent.Task.Time.now


sleep : Int -> Task x ()
sleep =
    Concurrent.Task.Process.sleep


getExternalTodo : Task Http.Error String
getExternalTodo =
    Http.request
        { url = "https://jsonplaceholder.typicode.com/todos/1"
        , method = "GET"
        , headers = []
        , body = Http.emptyBody
        , expect = Http.expectJson (Decode.field "title" Decode.string)
        , timeout = Nothing
        }


malformed : Task Http.Error String
malformed =
    Http.request
        { url = "http://localhost:4000/malformed"
        , method = "GET"
        , headers = []
        , body = Http.stringBody "text/html" "foo"
        , expect = Http.expectString
        , timeout = Nothing
        }


echoBody : Task Http.Error String
echoBody =
    Http.request
        { url = "http://localhost:4000/echo-body"
        , method = "POST"
        , headers = []
        , body = Http.jsonBody (Encode.object [ ( "hello", Encode.string "world" ) ])
        , expect = Http.expectJson (Decode.field "hello" Decode.string)
        , timeout = Nothing
        }


manyEnvs : Task Error String
manyEnvs =
    loadEnv
        (Env.succeed join5
            |> Env.required (Env.string "ONE")
            |> Env.required (Env.string "TWO")
            |> Env.required (Env.string "THREE")
            |> Env.required (Env.string "HOME")
            |> Env.required (Env.string "USER")
        )


loadEnv : Env.Parser a -> Task Error a
loadEnv =
    Env.load >> Task.mapError EnvError


slowSequence : Int -> Task Error String
slowSequence i =
    longRequest 1000
        |> andThenJoinWith (longRequest 1000)
        |> andThenJoinWith (longRequest 1000)
        |> andThenJoinWith (longRequest 1000)
        |> andThenJoinWith (longRequest i)


httpCombo : Task Error String
httpCombo =
    Task.map3 join3
        (longRequest 500
            |> andThenJoinWith (longRequest 500)
            |> andThenJoinWith (longRequest 50)
            |> andThenJoinWith (longRequest 50)
            |> andThenJoinWith (longRequest 20)
        )
        (longRequest 100
            |> andThenJoinWith (longRequest 100)
            |> andThenJoinWith (longRequest 500)
        )
        (Task.map2 join2
            (longRequest 70)
            (longRequest 80)
        )
        |> Task.andThen
            (\res ->
                Task.map (join2 res)
                    (Task.map3 join3
                        (longRequest 50)
                        (longRequest 100)
                        (longRequest 200)
                    )
            )


longRequest : Int -> Task Error String
longRequest =
    longRequest_ >> Task.mapError HttpError


longRequest_ : Int -> Task Http.Error String
longRequest_ ms =
    Http.request
        { url = "http://localhost:4000/wait-then-respond/" ++ String.fromInt ms
        , method = "GET"
        , headers = []
        , body = Http.emptyBody
        , expect = Http.expectJson (Decode.field "message" Decode.string)
        , timeout = Nothing
        }


getBigFile : Task Http.Error String
getBigFile =
    Http.request
        { url = "http://localhost:4000/big-file"
        , method = "GET"
        , headers = []
        , body = Http.emptyBody
        , expect = Http.expectJson Decode.string
        , timeout = Nothing
        }


httpError : Task Http.Error String
httpError =
    Http.request
        { url = "http://localhost:4000/boom"
        , method = "GET"
        , headers = []
        , body = Http.emptyBody
        , expect = Http.expectJson (Decode.succeed "whatever")
        , timeout = Nothing
        }


slowInts : Task Error String
slowInts =
    Task.map3 join3
        (doubleSlowInt 1)
        (doubleSlowInt 3)
        (doubleSlowInt 5)


doubleSlowInt : Int -> Task Error String
doubleSlowInt i =
    Task.map2 join2
        (slowInt i)
        (slowInt (i + 1))


slowInt : Int -> Task Error String
slowInt id =
    Task.define
        { function = "slowInt"
        , expect = Task.expectJson (Decode.map String.fromInt Decode.int)
        , errors = Task.expectThrows TaskError
        , args = Encode.int id
        }



-- Time Execution


timeExecution : String -> Task x a -> Task x a
timeExecution label task =
    consoleTime label
        |> Task.andThenDo
            (task
                |> Task.andThen
                    (\res ->
                        consoleTimeEnd label
                            |> Task.map (always res)
                    )
            )


consoleTime : String -> Task x ()
consoleTime label =
    Task.define
        { function = "console:time"
        , expect = Task.expectWhatever
        , errors = Task.catchAll ()
        , args = Encode.string label
        }


consoleTimeEnd : String -> Task x ()
consoleTimeEnd label =
    Task.define
        { function = "console:timeEnd"
        , expect = Task.expectWhatever
        , errors = Task.catchAll ()
        , args = Encode.string label
        }



-- Retry


retry : Int -> Task b a -> Task b a
retry n task =
    retry_ (Task.mapError (Tuple.pair n) task)
        |> Task.mapError Tuple.second


retry_ : Task ( Int, x ) a -> Task ( Int, x ) a
retry_ task =
    task
        |> Task.onError
            (\( n, err ) ->
                if n > 0 then
                    task
                        |> Task.mapError (Tuple.mapFirst (\n_ -> n_ - 1))
                        |> retry_

                else
                    Task.fail ( n, err )
            )



-- Helpers


join5 : String -> String -> String -> String -> String -> String
join5 a b c d e =
    join [ a, b, c, d, e ]


join4 : String -> String -> String -> String -> String
join4 a b c d =
    join [ a, b, c, d ]


join3 : String -> String -> String -> String
join3 a b c =
    join [ a, b, c ]


join2 : String -> String -> String
join2 a b =
    join [ a, b ]


join : List String -> String
join =
    String.join ", "



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ manualEnter OnManualEnter
        , fireMany OnFireMany
        , Task.onProgress
            { send = send
            , receive = receive
            , onProgress = OnProgress
            }
            model.tasks
        ]



-- Ports


port send : Decode.Value -> Cmd msg


port receive : (Decode.Value -> msg) -> Sub msg


port manualEnter : (String -> msg) -> Sub msg


port fireMany : (Int -> msg) -> Sub msg


port sendResult : String -> Cmd msg
