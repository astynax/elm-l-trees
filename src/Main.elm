module Main exposing (main, suite)

import Browser
import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as HA
import Html.Events as HE
import Parser as P exposing (Parser, grab, ignore)
import Parser.Common as PC
import Result

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Test exposing (..)


type Msg
    = EditRules String
    | EditPattern String
    | Tick


type alias Model =
    { rules : Result String Rules
    , rulesInput : String
    , patternInput : String
    , dirty : Bool
    , output : List String
    }


type alias Rules =
    Dict Char (List String)


main : Program () Model Msg
main =
    Browser.sandbox { init = init, view = view, update = update }


view : Model -> Html Msg
view model =
    Html.div []
        [ Html.textarea
            [ HA.value model.rulesInput
            , HE.onInput EditRules
            , HA.rows 10
            , HA.cols 40
            ]
            []
        , Html.pre [] [ Html.text (Debug.toString model.rules) ]
        ]


render : List String -> Rules -> List String
render _ _ =
    []


init : Model
init =
    let
        rulesExample =
            "\\\n\\/\n \\\n\n/\n  /\n\\/\n/"
    in
    { rules = parse rulesP rulesExample
    , rulesInput = rulesExample
    , patternInput = "\\/"
    , dirty = True
    , output = []
    }


update : Msg -> Model -> Model
update msg m =
    case msg of
        EditRules i ->
            { m | rulesInput = i, rules = parse rulesP i }
        EditPattern i ->
            { m | patternInput = i, dirty = True }
        Tick -> m


parse : Parser a -> String -> Result String a
parse p s =
    P.parse s p |> Result.mapError .message


ruleKeyP : Parser Char
ruleKeyP =
    P.when (\c -> c /= '\n' && c /= '\r')
        |> ignore (P.maybe (P.char '\r'))
        |> ignore (P.char '\n')


lineP : Parser String
lineP =
    P.stringWith (P.oneOrMore (P.when (\c -> c /= '\n' && c /= '\r')))
        |> ignore (P.maybe (P.char '\r'))
        |> ignore (P.maybe (P.char '\n'))


ruleP : Parser ( Char, List String )
ruleP =
    P.into Tuple.pair
        |> grab ruleKeyP
        |> grab (P.oneOrMore lineP)


blankLines : Parser ()
blankLines =
    P.zeroOrMore (P.oneOf [ P.char '\n', P.char '\r' ])
        |> P.map (\_ -> ())


rulesP : Parser Rules
rulesP =
    P.into Dict.fromList
        |> ignore blankLines
        |> grab (P.zeroOrMore (ruleP |> ignore blankLines))
        |> ignore P.end


-- * Tests

suite : Test
suite =
    describe "Rule parser"
        [ test "parses canonical README example" <|
            \_ ->
                let
                    input =
                        "\\\n\\/\n \\\n\n/\n  /\n\\/\n/"

                    expected =
                        Dict.fromList
                            [ ( '\\', [ "\\/", " \\" ] )
                            , ( '/', [ "  /", "\\/", "/" ] )
                            ]
                in
                Expect.equal (Ok expected) (parse rulesP input)
        , test "parses single rule with multi-line block" <|
            \_ ->
                let
                    input =
                        "X\nABC\nDEF"

                    expected =
                        Dict.fromList [ ( 'X', [ "ABC", "DEF" ] ) ]
                in
                Expect.equal (Ok expected) (parse rulesP input)
        , test "parses empty input" <|
            \_ ->
                Expect.equal (Ok Dict.empty) (parse rulesP "")
        , test "parses input with only blank lines" <|
            \_ ->
                Expect.equal (Ok Dict.empty) (parse rulesP "\n\n\n")
        , test "parses rules with extra separating blank lines and trailing newlines" <|
            \_ ->
                let
                    input =
                        "\n\nX\n1\n\n\nY\n2\n\n"

                    expected =
                        Dict.fromList
                            [ ( 'X', [ "1" ] )
                            , ( 'Y', [ "2" ] )
                            ]
                in
                Expect.equal (Ok expected) (parse rulesP input)
        , test "preserves leading whitespace in block lines" <|
            \_ ->
                let
                    input =
                        "K\n  A\n   B\n C"

                    expected =
                        Dict.fromList [ ( 'K', [ "  A", "   B", " C" ] ) ]
                in
                Expect.equal (Ok expected) (parse rulesP input)
        , test "fails on multi-character key line" <|
            \_ ->
                Expect.err (parse rulesP "AB\nXYZ")
        , test "fails on key without block" <|
            \_ ->
                Expect.err (parse rulesP "A\n")
        , test "fails on single character key without newline" <|
            \_ ->
                Expect.err (parse rulesP "A")
        , test "fails on invalid key in subsequent rule" <|
            \_ ->
                Expect.err (parse rulesP "A\n1\n\nBC\n2")
        , test "update handles EditRules message" <|
            \_ ->
                let
                    newRulesInput =
                        "X\nABC"

                    updated =
                        update (EditRules newRulesInput) init
                in
                Expect.all
                    [ \m -> Expect.equal newRulesInput m.rulesInput
                    , \m -> Expect.equal (Ok (Dict.fromList [ ( 'X', [ "ABC" ] ) ])) m.rules
                    ]
                    updated
        ]
