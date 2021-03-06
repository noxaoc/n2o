-module(wf_render_actions).
-author('Andrew Zadorozhny').
-include_lib ("n2o/include/wf.hrl").
-compile(export_all).

render_actions(Actions) -> render_actions(Actions, undefined).
render_actions(Actions, Anchor) -> render_actions(Actions, Anchor, Anchor).
render_actions(Actions, Trigger, Target) ->
    Script = inner_render_actions(Actions, Trigger, Target),
    {ok, Script}.

inner_render_actions(Action, Trigger, Target) ->
    if
        Action == [] -> [];
        Action == undefined -> [];
        is_binary(Action)   -> [Action];
        ?IS_STRING(Action)  -> [Action];
        is_tuple(Action)    -> inner_render_action(Action, Trigger, Target);
        is_list(Action)     -> [inner_render_actions(hd(Action), Trigger, Target) |
                                inner_render_actions(tl(Action), Trigger, Target) ];
                       true -> throw({unanticipated_case_in_render_actions, Action}) end.

inner_render_action(Action, Trigger, Target) when is_tuple(Action) ->
    Base = wf_utils:get_actionbase(Action),
    Module = Base#actionbase.module, 
    case Base#actionbase.is_action == is_action of
        true -> ok;
        false -> throw({not_an_action, Action})
    end,
    case Base#actionbase.show_if of 
        true -> 
            Trigger1 = wf:coalesce([Base#actionbase.trigger, Trigger]),
            Trigger2 = normalize_path(Trigger1),
            Target1  = wf:coalesce([Base#actionbase.target, Target]),
            Target2  = normalize_path(Target1),
            Base1 = Base#actionbase {
                trigger = Trigger2,
                target = Target2
            },
            Action1 = wf_utils:replace_with_base(Base1, Action),
            ActionScript = call_action_render(Module, Action1, Trigger2, Target2),
            case ActionScript /= undefined andalso lists:flatten(ActionScript) /= [] of
                true  -> [ActionScript];
                false -> []
            end;
        _ -> 
            []
    end.

call_action_render(Module, Action, Trigger, Target) ->
    {module, Module} = code:ensure_loaded(Module),
    NewActions = Module:render_action(Action),
    inner_render_actions(NewActions, Trigger, Target).

normalize_path(undefined) -> undefined;
normalize_path(page) -> "page";
normalize_path(Path) when is_atom(Path) ->
    String = atom_to_list(Path),
    Tokens = string:tokens(String, "."),
    Tokens1 = [ "#"++X || X <- Tokens],
    string:join(Tokens1, " ");
normalize_path(String) ->
    case String of
        "wfid_" ++ _ -> "." ++ String;
        "temp" ++ S -> "temp" ++ S; % ".wfid_" ++ 
                    %    String;
        _ -> String % wf_utils:replace(String, "##", ".wfid_")
    end.

to_js_id(P) ->
    P1 = lists:reverse(P),
    string:join(P1, ".").
