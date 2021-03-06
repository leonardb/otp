%%
%% %CopyrightBegin%
%%
%% Copyright Ericsson AB 2020. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
%% %CopyrightEnd%
%%

-module(erl_stdlib_errors).
-export([format_error/2]).

-spec format_error(Reason, StackTrace) -> ErrorMap when
      Reason :: term(),
      StackTrace :: [term()],
      ErrorMap :: #{pos_integer() => unicode:chardata()}.

format_error(_Reason, [{M,F,As,Info}|_]) ->
    ErrorInfoMap = proplists:get_value(error_info, Info, #{}),
    Cause = maps:get(cause, ErrorInfoMap, none),
    Res = case M of
              binary ->
                  format_binary_error(F, As, Cause);
              ets ->
                  format_ets_error(F, As, Cause);
              lists ->
                  format_lists_error(F, As);
              maps ->
                  format_maps_error(F, As);
              math ->
                  format_math_error(F, As);
              re ->
                  format_re_error(F, As, Cause);
              unicode ->
                  format_unicode_error(F, As);
              _ ->
                  []
          end,
    format_error_map(Res, 1, #{}).

format_binary_error(at, [Subject,Pos], _) ->
    [must_be_binary(Subject), must_be_position(Pos)];
format_binary_error(bin_to_list, [Subject], _) ->
    [must_be_binary(Subject)];
format_binary_error(bin_to_list, Args, Cause) ->
    format_binary_error(part, Args, Cause);
format_binary_error(compile_pattern, [_], _) ->
    [<<"not a valid pattern">>];
format_binary_error(copy, [Subject], _) ->
    [must_be_binary(Subject)];
format_binary_error(copy, [Subject, N], _) ->
    [must_be_binary(Subject), must_be_non_neg_integer(N)];
format_binary_error(decode_unsigned, [Subject], _) ->
    [must_be_binary(Subject)];
format_binary_error(decode_unsigned, [Subject, Endianness], _) ->
    [must_be_binary(Subject), must_be_endianness(Endianness)];
format_binary_error(encode_unsigned, [Subject], _) ->
    [must_be_non_neg_integer(Subject)];
format_binary_error(encode_unsigned, [Subject, Endianness], _) ->
    [must_be_non_neg_integer(Subject), must_be_endianness(Endianness)];
format_binary_error(first, [Subject], _) ->
    [case Subject of
         <<>> -> empty_binary;
        _ -> must_be_binary(Subject)
     end];
format_binary_error(last, [Subject], _) ->
    [case Subject of
         <<>> -> empty_binary;
        _ -> must_be_binary(Subject)
     end];
format_binary_error(list_to_bin, [_], _) ->
    [not_iodata];
format_binary_error(longest_common_prefix, [_], _) ->
    [bad_binary_list];
format_binary_error(longest_common_suffix, [_], _) ->
    [bad_binary_list];
format_binary_error(match, [Subject, Pattern], _) ->
    [must_be_binary(Subject), must_be_pattern(Pattern)];
format_binary_error(match, [Subject, Pattern, Options], _) ->
    case [must_be_binary(Subject), must_be_pattern(Pattern)] of
        [[], []] ->
            case Options of
                [{scope,{Start,Len}}] when is_integer(Start),
                                           is_integer(Len) ->
                    [[], [], <<"specified part is not wholly inside binary">>];
                _ ->
                    [[], [], bad_options]
            end;
        Errors ->
            Errors
    end;
format_binary_error(matches, Args, Cause) ->
    format_binary_error(match, Args, Cause);
format_binary_error(part=Name, [Subject, PosLen], Cause) ->
    case PosLen of
        {Pos,Len} when is_integer(Pos), is_integer(Len) ->
            case format_binary_error(Name, [Subject,Pos,Len], Cause) of
                [Arg1,[],[]] ->
                    [Arg1];
                [Arg1,_,_] ->
                    [Arg1,range]
            end;
        _ ->
            [must_be_binary(Subject),<<"not a valid {Pos,Length} tuple">>]
    end;
format_binary_error(part, [Subject, Pos, Len], _) ->
    case [must_be_binary(Subject),must_be_position(Pos),must_be_integer(Len)] of
        [[],[],[]] ->
            Arg2 = if
                       Pos > byte_size(Subject) -> range;
                       true -> []
                   end,
            case Arg2 of
                [] -> [[],[],range];
                range -> [[],Arg2]
            end;
        Errors ->
            Errors
    end;
format_binary_error(referenced_byte_size, [Subject], _) ->
    [must_be_binary(Subject)];
format_binary_error(split, [Subject, Pattern], _) ->
    [must_be_binary(Subject), must_be_pattern(Pattern)];
format_binary_error(split, [Subject, Pattern, _Options], _) ->
    case [must_be_binary(Subject), must_be_pattern(Pattern)] of
        [[], []] ->
            [[], [], bad_options];
        Errors ->
            Errors
    end;
format_binary_error(replace, [Subject, Pattern, Replacement], _) ->
    [must_be_binary(Subject),
     must_be_pattern(Pattern),
     must_be_binary(Replacement)];
format_binary_error(replace, [Subject, Pattern, Replacement, _Options], Cause) ->
    Errors = format_binary_error(replace, [Subject, Pattern, Replacement], Cause),
    case Cause of
        badopt ->
            Errors ++ [bad_options];
        _ ->
            case Errors of
                [[], [], []] ->
                    %% Options are syntactically correct, but not semantically
                    %% (e.g. referencing outside the subject).
                    [[], [], [], bad_options];
                _ ->
                    Errors
            end
    end.

format_lists_error(keyfind, [_Key, Pos, List]) ->
    PosError = if
                   is_integer(Pos) ->
                       if Pos < 1 -> range;
                          true -> []
                       end;
                   true ->
                       not_integer
               end,
    [[], PosError, must_be_list(List)];
format_lists_error(keymember, Args) ->
    format_lists_error(keyfind, Args);
format_lists_error(keysearch, Args) ->
    format_lists_error(keyfind, Args);
format_lists_error(member, [_Key, List]) ->
    [[], must_be_list(List)];
format_lists_error(reverse, [List, _Acc]) ->
    [must_be_list(List)].

format_maps_error(filter, Args) ->
    format_maps_error(map, Args);
format_maps_error(filtermap, Args) ->
    format_maps_error(map, Args);
format_maps_error(find, _Args) ->
    [[], not_map];
format_maps_error(fold, [Pred, _Init, Map]) ->
    [must_be_fun(Pred, 3), [], must_be_map_or_iter(Map)];
format_maps_error(from_keys, [List, _]) ->
    [must_be_list(List)];
format_maps_error(from_list, [List]) ->
    [must_be_list(List)];
format_maps_error(get, _Args) ->
    [[], not_map];
format_maps_error(intersect, [Map1, Map2]) ->
    [must_be_map(Map1), must_be_map(Map2)];
format_maps_error(intersect_with, [Combiner, Map1, Map2]) ->
    [must_be_fun(Combiner, 3), must_be_map(Map1), must_be_map(Map2)];
format_maps_error(is_key, _Args) ->
    [[], not_map];
format_maps_error(iterator, _Args) ->
    [not_map];
format_maps_error(keys, _Args) ->
    [not_map];
format_maps_error(map, [Pred, Map]) ->
    [must_be_fun(Pred, 2), must_be_map_or_iter(Map)];
format_maps_error(merge, [Map1, Map2]) ->
    [must_be_map(Map1), must_be_map(Map2)];
format_maps_error(merge_with, [Combiner, Map1, Map2]) ->
    [must_be_fun(Combiner, 3), must_be_map(Map1), must_be_map(Map2)];
format_maps_error(put, _Args) ->
    [[], [], not_map];
format_maps_error(next, _Args) ->
    [bad_iterator];
format_maps_error(remove, _Args) ->
    [[], not_map];
format_maps_error(size, _Args) ->
    [not_map];
format_maps_error(take, _Args) ->
    [[], not_map];
format_maps_error(to_list, _Args) ->
    [not_map];
format_maps_error(update, _Args) ->
    [[], [], not_map];
format_maps_error(update_with, [_Key, Fun, Map]) ->
    [[], must_be_fun(Fun, 1), must_be_map(Map)];
format_maps_error(update_with, [_Key, Fun, _Init, Map]) ->
    [[], must_be_fun(Fun, 1), [], must_be_map(Map)];
format_maps_error(values, _Args) ->
    [not_map];
format_maps_error(with, [List, Map]) ->
    [must_be_list(List), must_be_map(Map)];
format_maps_error(without, [List, Map]) ->
    [must_be_list(List), must_be_map(Map)].

format_math_error(acos, Args) ->
    maybe_domain_error(Args);
format_math_error(acosh, Args) ->
    maybe_domain_error(Args);
format_math_error(asin, Args) ->
    maybe_domain_error(Args);
format_math_error(atanh, Args) ->
    maybe_domain_error(Args);
format_math_error(log, Args) ->
    maybe_domain_error(Args);
format_math_error(log2, Args) ->
    maybe_domain_error(Args);
format_math_error(log10, Args) ->
    maybe_domain_error(Args);
format_math_error(sqrt, Args) ->
    maybe_domain_error(Args);
format_math_error(fmod, [Arg1, Arg2]) ->
    case [must_be_number(Arg1), must_be_number(Arg2)] of
        [[], []] ->
            if
                Arg2 == 0 -> [[], domain_error];
                true -> []
            end;
        Error ->
            Error
    end;
format_math_error(_, [Arg]) ->
    [must_be_number(Arg)];
format_math_error(_, [Arg1, Arg2]) ->
    [must_be_number(Arg1), must_be_number(Arg2)].

maybe_domain_error([Arg]) ->
    case must_be_number(Arg) of
        [] -> [domain_error];
        Error -> [Error]
    end.

format_re_error(compile, [_], _) ->
    [not_iodata];
format_re_error(compile, [Re, _Options], Cause) ->
    ReError = try re:compile(Re) of
                  _ -> []
              catch
                  _:_ -> not_iodata
              end,
    case Cause of
        badopt ->
            [ReError, bad_options];
        _ ->
            [ReError]
    end;
format_re_error(inspect, [CompiledRE, Item], _) ->
    ReError = try re:inspect(CompiledRE, namelist) of
                  _ -> []
              catch
                  error:_ -> not_compiled_regexp
              end,
    if
        ReError =:= []; not is_atom(Item) ->
            [ReError, <<"not a valid item">>];
        true ->
            [ReError]
    end;
format_re_error(replace, [Subject, RE, Replacement], _) ->
    [must_be_iodata(Subject),
     must_be_regexp(RE),
     must_be_iodata(Replacement)];
format_re_error(replace, [Subject, RE, Replacement, _Options], Cause) ->
    Errors = [must_be_iodata(Subject),
              must_be_regexp(RE),
              must_be_iodata(Replacement)],
    case Cause of
        badopt ->
            Errors ++ [bad_options];
        _ ->
            Errors
    end;
format_re_error(run, [Subject, RE], _) ->
    [must_be_iodata(Subject), must_be_regexp(RE)];
format_re_error(run, [Subject, RE, _Options], Cause) ->
    Errors = [must_be_iodata(Subject), must_be_regexp(RE)],
    case Cause of
        badopt ->
            Errors ++ [bad_options];
        _ ->
            Errors
    end;
format_re_error(split, [Subject, RE], _) ->
    [must_be_iodata(Subject), must_be_regexp(RE)];
format_re_error(split, [Subject, RE, _Options], Cause) ->
    Errors = [must_be_iodata(Subject), must_be_regexp(RE)],
    case Cause of
        badopt ->
            Errors ++ [bad_options];
        _ ->
            Errors
    end.

format_unicode_error(characters_to_binary, [_]) ->
    [bad_char_data];
format_unicode_error(characters_to_binary, [Chars, InEnc]) ->
    [unicode_char_data(Chars), unicode_encoding(InEnc)];
format_unicode_error(characters_to_binary, [Chars, InEnc, OutEnc]) ->
    [unicode_char_data(Chars), unicode_encoding(InEnc), unicode_encoding(OutEnc)];
format_unicode_error(characters_to_list, Args) ->
    format_unicode_error(characters_to_binary, Args);
format_unicode_error(characters_to_nfc_binary, [_]) ->
    [bad_char_data];
format_unicode_error(characters_to_nfc_list, [_]) ->
    [bad_char_data];
format_unicode_error(characters_to_nfd_binary, [_]) ->
    [bad_char_data];
format_unicode_error(characters_to_nfd_list, [_]) ->
    [bad_char_data];
format_unicode_error(characters_to_nfkc_binary, [_]) ->
    [bad_char_data];
format_unicode_error(characters_to_nfkc_list, [_]) ->
    [bad_char_data];
format_unicode_error(characters_to_nfkd_binary, [_]) ->
    [bad_char_data];
format_unicode_error(characters_to_nfkd_list, [_]) ->
    [bad_char_data].

unicode_char_data(Chars) ->
    try unicode:characters_to_binary(Chars) of
        _ ->
            []
    catch
        error:_ ->
            bad_char_data
    end.

unicode_encoding(Enc) ->
    try unicode:characters_to_binary(<<"a">>, Enc) of
        _ ->
            []
    catch
        error:_ ->
            bad_encoding
    end.

format_ets_error(delete_object, Args, Cause) ->
    format_object(Args, Cause);
format_ets_error(give_away, [_Tab,Pid,_Gift]=Args, Cause) ->
    TabCause = format_cause(Args, Cause),
    case Cause of
        owner ->
            [TabCause, already_owner];
        not_owner ->
            [TabCause, not_owner];
        _ ->
            [TabCause,
             case {is_pid(Pid),TabCause} of
                 {true,""} ->
                     dead_process;
                 {false,_} ->
                     not_pid;
                 _ ->
                     ""
             end]
    end;
format_ets_error(info, Args, Cause) ->
    format_default(bad_info_item, Args, Cause);
format_ets_error(insert, Args, Cause) ->
    format_objects(Args, Cause);
format_ets_error(insert_new, Args, Cause) ->
    format_objects(Args, Cause);
format_ets_error(lookup_element, [_,_,Pos]=Args, Cause) ->
    TabCause = format_cause(Args, Cause),
    PosCause = format_non_negative_integer(Pos),
    case Cause of
        badkey ->
            [TabCause, bad_key, PosCause];
        _ ->
            case {TabCause,PosCause} of
                {"",""} ->
                    ["", "", <<"position is greater than the size of the object">>];
                {_,_} ->
                    [TabCause, "", PosCause]
            end
    end;
format_ets_error(match, [_], _Cause) ->
    [bad_continuation];
format_ets_error(match, [_,_,_]=Args, Cause) ->
    format_limit(Args, Cause);
format_ets_error(match_object, [_], _Cause) ->
    [bad_continuation];
format_ets_error(match_object, [_,_,_]=Args, Cause) ->
    format_limit(Args, Cause);
format_ets_error(next, Args, Cause) ->
    format_default(bad_key, Args, Cause);
format_ets_error(prev, Args, Cause) ->
    format_default(bad_key, Args, Cause);
format_ets_error(rename, [_,NewName]=Args, Cause) ->
    case [format_cause(Args, Cause),
          if
              is_atom(NewName) -> "";
              true -> bad_table_name
          end] of
        ["", ""] ->
            ["", name_already_exists];
        Result ->
            Result
    end;
format_ets_error(safe_fixtable, Args, Cause) ->
    format_default(bad_boolean, Args, Cause);
format_ets_error(select, [_], _Cause) ->
    [bad_continuation];
format_ets_error(select, [_,_]=Args, Cause) ->
    format_default(bad_matchspec, Args, Cause);
format_ets_error(select, [_,_,_]=Args, Cause) ->
    format_ms_limit(Args, Cause);
format_ets_error(select_count, [_,_]=Args, Cause) ->
    format_default(bad_matchspec, Args, Cause);
format_ets_error(select_count, [_,_,_]=Args, Cause) ->
    format_ms_limit(Args, Cause);
format_ets_error(internal_select_delete, Args, Cause) ->
    format_default(bad_matchspec, Args, Cause);
format_ets_error(select_replace, Args, Cause) ->
    format_default(bad_matchspec, Args, Cause);
format_ets_error(select_reverse, [_,_]=Args, Cause) ->
    format_default(bad_matchspec, Args, Cause);
format_ets_error(select_reverse, [_,_,_]=Args, Cause) ->
    format_ms_limit(Args, Cause);
format_ets_error(setopts, Args, Cause) ->
    format_default(bad_options, Args, Cause);
format_ets_error(slot, Args, Cause) ->
    format_default(range, Args, Cause);
format_ets_error(update_counter, [_,_,UpdateOp]=Args, Cause) ->
    TabCause = format_cause(Args, Cause),
    case Cause of
        badkey ->
            [TabCause, bad_key, format_update_op(UpdateOp)];
        keypos ->
            [TabCause, "", same_as_keypos];
        position ->
            [TabCause, "", update_op_range];
        none ->
            case is_update_op_top(UpdateOp) of
                false ->
                    [TabCause, "", bad_update_op];
                true ->
                    %% This is the only possible remaining error.
                    [TabCause, "", counter_not_integer]
            end;
        _ ->
            [TabCause, "", format_update_op(UpdateOp)]
    end;
format_ets_error(update_counter, [_,_,UpdateOp,Default]=Args, Cause) ->
    case format_cause(Args, Cause) of
        TabCause when TabCause =/= [] ->
            [TabCause];
        "" ->
            %% The table is OK. The error is in one or more of the
            %% other arguments.
            TupleCause = format_tuple(Default),
            case Cause of
                badkey ->
                    ["", bad_key, format_update_op(UpdateOp) | TupleCause];
                keypos ->
                    ["", "", same_as_keypos | TupleCause];
                position ->
                    ["", "", update_op_range];
                _ ->
                    case {format_update_op(UpdateOp),TupleCause} of
                        {"",[""]} ->
                            %% UpdateOp and Default are individually
                            %% OK. The only possible remaining
                            %% problem is that the value in the record
                            %% is not an integer.
                            ["", "", counter_not_integer];
                        {UpdateOpCause,_} ->
                            ["", "", UpdateOpCause | TupleCause]
                    end
            end
    end;
format_ets_error(update_element, [_,_,ElementSpec]=Args, Cause) ->
    TabCause = format_cause(Args, Cause),
    [TabCause, "" |
     case Cause of
         keypos ->
             [same_as_keypos];
         _ ->
             case is_element_spec_top(ElementSpec) of
                 true ->
                     case TabCause of
                         [] ->
                             [range];
                         _ ->
                             []
                     end;
                 false ->
                     [<<"is not a valid element specification">>]
             end
     end];
format_ets_error(whereis, _Args, _Cause) ->
    [bad_table_name];
format_ets_error(_, Args, Cause) ->
    [format_cause(Args, Cause)].

format_default(Default, Args, Cause) ->
    case format_cause(Args, Cause) of
        "" -> ["",Default];
        Error -> [Error]
    end.

is_element_spec_top(List) when is_list(List) ->
    lists:all(fun is_element_spec/1, List);
is_element_spec_top(Other) ->
    is_element_spec(Other).

is_element_spec({Pos, _Value}) when is_integer(Pos), Pos > 0 ->
    true;
is_element_spec(_) ->
    false.

format_ms_limit([_,Ms,_]=Args, Cause) ->
    [Tab, [], Limit] = format_limit(Args, Cause),
    case is_match_spec(Ms) of
        true ->
            [Tab, "", Limit];
        false ->
            [Tab, bad_matchspec, Limit]
    end.

format_limit([_,_,Limit]=Args, Cause) ->
    [format_cause(Args, Cause), "", format_non_negative_integer(Limit)].

format_non_negative_integer(N) ->
     if
         not is_integer(N) -> not_integer;
         N < 1 -> range;
         true -> ""
     end.

format_object([_,Object|_]=Args, Cause) ->
    [format_cause(Args, Cause) | format_tuple(Object)].

format_tuple(Term) ->
    if tuple_size(Term) > 0 -> [""];
       is_tuple(Term) -> [empty_tuple];
       true -> [not_tuple]
    end.

format_objects([_,Term|_]=Args, Cause) ->
    [format_cause(Args, Cause) |
     if tuple_size(Term) > 0 -> [];
        is_tuple(Term) -> [empty_tuple];
        is_list(Term) ->
             try lists:all(fun(T) -> tuple_size(T) > 0 end, Term) of
                 true -> [];
                 false -> [not_tuple_or_list]
             catch
                 _:_ ->
                     [not_tuple_or_list]
             end;
        true -> [not_tuple]
     end].

format_cause(Args, Cause) ->
    case Cause of
        none ->
            "";
        type ->
            case Args of
                [Ref|_] when is_reference(Ref) ->
                    <<"not a valid table identifier">>;
                _ ->
                    <<"not an atom or a table identifier">>
            end;
        id ->
            <<"the table identifier does not refer to an existing ETS table">>;
        access ->
            <<"the table identifier refers to an ETS table with insufficient access rights">>;
        table_type ->
            <<"the table identifier refers to an ETS table of a type not supported by this operation">>;
        %% The following error reasons don't have anything to do with
        %% the table argument, but with some of the other arguments.
        badkey ->
            "";
        keypos ->
            "";
        position ->
            "";
        owner ->
            "";
        not_owner ->
            ""
    end.

is_match_spec(Term) ->
    ets:is_compiled_ms(Term) orelse
        try ets:match_spec_compile(Term) of
            _ ->
                true
        catch
            error:badarg ->
                false
        end.

format_update_op(UpdateOp) ->
    case is_update_op_top(UpdateOp) of
        true -> "";
        false -> bad_update_op
    end.

is_update_op_top(List) when is_list(List) ->
    lists:all(fun is_update_op/1, List);
is_update_op_top(Op) ->
    is_update_op(Op).

is_update_op({Pos, Incr}) when is_integer(Pos), is_integer(Incr) ->
    true;
is_update_op({Pos, Incr, Threshold, SetValue})
  when is_integer(Pos), is_integer(Incr), is_integer(Threshold), is_integer(SetValue) ->
    true;
is_update_op(Incr) ->
    is_integer(Incr).

format_error_map([""|Es], ArgNum, Map) ->
    format_error_map(Es, ArgNum + 1, Map);
format_error_map([E|Es], ArgNum, Map) ->
    format_error_map(Es, ArgNum + 1, Map#{ArgNum => expand_error(E)});
format_error_map([], _, Map) ->
    Map.

must_be_binary(Bin) ->
    must_be_binary(Bin, []).

must_be_binary(Bin, Error) when is_binary(Bin) -> Error;
must_be_binary(Bin, _Error) when is_bitstring(Bin) -> bitstring;
must_be_binary(_, _) -> not_binary.

must_be_endianness(little) -> [];
must_be_endianness(big) -> [];
must_be_endianness(_) -> bad_endian.

must_be_fun(F, Arity) when is_function(F, Arity) -> [];
must_be_fun(_, Arity) -> {not_fun,Arity}.

must_be_integer(N) when is_integer(N) -> [];
must_be_integer(_) -> not_integer.

must_be_integer(N, Min, Max, Default) when is_integer(N) ->
    if
        Min =< N, N =< Max ->
            Default;
        true ->
            range
    end;
must_be_integer(_, _, _, _) -> not_integer.

must_be_integer(N, Min, Max) ->
    must_be_integer(N, Min, Max, []).

must_be_non_neg_integer(N) ->
    must_be_integer(N, 0, infinity).

must_be_iodata(Term) ->
    try iolist_size(Term) of
        _ -> []
    catch
        error:_ -> not_iodata
    end.

must_be_list(List) when is_list(List) ->
    try length(List) of
        _ ->
            []
    catch
        error:badarg ->
            not_proper_list
    end;
must_be_list(_) ->
    not_list.

must_be_map(#{}) -> [];
must_be_map(_) -> not_map.

must_be_map_or_iter(Map) when is_map(Map) ->
    [];
must_be_map_or_iter(Iter) ->
    try maps:next(Iter) of
        _ -> []
    catch
        error:_ ->
            not_map_or_iterator
    end.

must_be_number(N) ->
    if
        is_number(N) -> [];
        true -> not_number
    end.

must_be_pattern(P) ->
    try binary:match(<<"a">>, P) of
        _ ->
            []
    catch
        error:badarg ->
            bad_binary_pattern
    end.

must_be_position(Pos) when is_integer(Pos), Pos >= 0 -> [];
must_be_position(Pos) when is_integer(Pos) -> range;
must_be_position(_) -> not_integer.

must_be_regexp(Term) ->
    try re:run("", Term) of
        _ -> []
    catch
        error:_ -> not_regexp
    end.

expand_error(already_owner) ->
    <<"the process is already the owner of the table">>;
expand_error(bad_boolean) ->
    <<"not a boolean value">>;
expand_error(bad_binary_list) ->
    <<"not a flat list of binaries">>;
expand_error(bad_char_data) ->
    <<"not valid character data (an iodata term)">>;
expand_error(bad_binary_pattern) ->
    <<"not a valid pattern">>;
expand_error(bad_continuation) ->
    <<"invalid continuation">>;
expand_error(bad_encoding) ->
    <<"not a valid encoding">>;
expand_error(bad_endinanness) ->
    <<"must be 'big' or 'little'">>;
expand_error(bad_info_item) ->
    <<"not a valid info item">>;
expand_error(bad_iterator) ->
    <<"not a valid iterator">>;
expand_error(bad_key) ->
    <<"not a key that exists in the table">>;
expand_error(bad_matchspec) ->
    <<"not a valid match specification">>;
expand_error(bad_options) ->
    <<"invalid options">>;
expand_error(bad_table_name) ->
    <<"invalid table name (must be an atom)">>;
expand_error(bad_update_op) ->
    <<"not a valid update operation">>;
expand_error(bitstring) ->
    <<"is a bitstring (expected a binary)">>;
expand_error(counter_not_integer) ->
    <<"the value in the given position, in the object, is not an integer">>;
expand_error(dead_process) ->
    <<"the pid refers to a terminated process">>;
expand_error(domain_error) ->
    <<"is outside the domain for this function">>;
expand_error(empty_binary) ->
    <<"a zero-sized binary is not allowed">>;
expand_error(empty_tuple) ->
    <<"is an empty tuple">>;
expand_error(name_already_exists) ->
    <<"table name already exists">>;
expand_error(not_binary) ->
    <<"not a binary">>;
expand_error(not_compiled_regexp) ->
    <<"not a compiled regular expression">>;
expand_error(not_iodata) ->
    <<"not an iodata term">>;
expand_error({not_fun,1}) ->
    <<"not a fun that takes one argument">>;
expand_error({not_fun,2}) ->
    <<"not a fun that takes two arguments">>;
expand_error({not_fun,3}) ->
    <<"not a fun that takes three arguments">>;
expand_error(not_integer) ->
    <<"not an integer">>;
expand_error(not_list) ->
    <<"not a list">>;
expand_error(not_map_or_iterator) ->
    <<"not a map or an iterator">>;
expand_error(not_number) ->
    <<"not a number">>;
expand_error(not_proper_list) ->
    <<"not a proper list">>;
expand_error(not_map) ->
    <<"not a map">>;
expand_error(not_owner) ->
    <<"the current process is not the owner">>;
expand_error(not_pid) ->
    <<"not a pid">>;
expand_error(not_regexp) ->
    <<"neither an iodata term nor a compiled regular expression">>;
expand_error(not_tuple) ->
    <<"not a tuple">>;
expand_error(not_tuple_or_list) ->
    <<"not a non-empty tuple or a list of non-empty tuples">>;
expand_error(range) ->
    <<"out of range">>;
expand_error(same_as_keypos) ->
    <<"the position is the same as the key position">>;
expand_error(update_op_range) ->
    <<"the position in the update operation is out of range">>;
expand_error(Other) ->
    Other.
