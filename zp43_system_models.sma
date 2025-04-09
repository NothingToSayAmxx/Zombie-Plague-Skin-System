/**
    History of changes:
        - 1.1 beta (20.05.2022) - First release.
        - 1.2 (17.12.2022) - Edit bug with checks (Thanks cookie.).
        - 1.3 (11.03.2023) - Code changes, added ability to set validity time.
        - 1.4 (11.07.2024) - Another code refactoring. Replaced RequestFrame with set_task (because of zombie mod).
        - 1.5 (09.04.2025) - Fixed bug (https://dev-cs.ru/threads/22410/post-194149), refactored code, added new check type: GameCMS.

    Acknowledgements: b0t.
*/

#include <amxmodx>
#tryinclude <gamecms5>
#include <reapi>
#include <zombieplague>

#define ModType 1 // 1 - Zombie Plague Advanced, 2 - Zombie Plague 4.3

const TaskId__UpdateModel = 73241;

#if ModType == 1
    native zp_set_user_model(UserId, szModelName[]);
#else
    native zp_override_user_model(UserId, szModelName[], iModelIndex);
#endif

enum {
    Section__None,
    Section__Settings,
    Section__Models
};

enum any: eSettingsData {
    Float: Setting__TaskTime,
    Setting__CheckFlagsType,
    Setting__Command[32]
};

enum any: eArrayData {
    Array__Key[32],
    Array__Value[64],
    Array__ModelName[64],
    Array__ModelBody,
    Array__ModelSkin,
    Array__Time,
    Array__ModelIndex
};

new const Config__Name[] = "re_zpmodels.ini"; // Config path.
new const Plugin__Version[] = "1.5"; // Plugin version.

new 
    g__iSection,
    g__eSettings[eSettingsData],
    p__iModelIndex[MAX_PLAYERS + 1],
    Array: g__aModels;

public plugin_precache() {
    Func__ReadFile();

    if(!ArraySize(g__aModels)) {
        log_amx("Plugin has no models! Check your config file.");
        pause("ad");
    }
}

public plugin_init() {
    register_plugin("[ZP 4.3] System: Models", Plugin__Version, "ImmortalAmxx");
    register_dictionary("ZP43_SystemModels.txt");

    if(g__eSettings[Setting__Command][0]) {
        RegisterAllCmd(g__eSettings[Setting__Command], "Command__CheckModelInfo");
    }

    RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer__Spawn_Post", true);
}

public client_putinserver(UserId) {
    p__iModelIndex[UserId] = -1;

    for(new iCase, ArrayData[eArrayData]; iCase < ArraySize(g__aModels); iCase++) {
        ArrayGetArray(g__aModels, iCase, ArrayData);

        static szKey[64];
        switch(ArrayData[Array__Key]) {
            case 's', 'S': {
                get_user_authid(UserId, szKey, charsmax(szKey));

                if(equal(szKey, ArrayData[Array__Value])) {
                    p__iModelIndex[UserId] = iCase;
                    break;
                }                
            }
            case 'f', 'F': {
                if(CheckPlayerFlags(UserId, ArrayData[Array__Value], g__eSettings[Setting__CheckFlagsType])) {
                    p__iModelIndex[UserId] = iCase;
                    break;
                }
            }
            case 'i', 'I': {
                get_user_ip(UserId, szKey, charsmax(szKey), 1);

                if(equal(szKey, ArrayData[Array__Value])) {
                    p__iModelIndex[UserId] = iCase;
                    break;              
                }
            }
            case 'n', 'N': {
                get_user_name(UserId, szKey, charsmax(szKey));

                if(equal(szKey, ArrayData[Array__Value])) {
                    p__iModelIndex[UserId] = iCase;
                    break;              
                }
            }
            case 'g', 'G': {
                if(cmsapi_get_user_services(UserId, "", ArrayData[Array__Value])) {
                    p__iModelIndex[UserId] = iCase;
                    break;
                }
            }
        }
    }
}

public Command__CheckModelInfo(const UserId) {
    if(p__iModelIndex[UserId] == -1) {
        client_print_color(UserId, print_team_default, "%L %L", UserId, "ZpModels__Prefix", UserId, "ZpModels__Print_Model_Not_Found");
        return PLUGIN_HANDLED;
    }

    new ArrayData[eArrayData];
    ArrayGetArray(g__aModels, p__iModelIndex[UserId], ArrayData);

    new szTimeFormat[32];

    if(ArrayData[Array__Time] == 0) {
        formatex(szTimeFormat, charsmax(szTimeFormat), "%L", UserId, "ZpModels__Print_ModelLifeTime");
    }
    else {
        format_time(szTimeFormat, charsmax(szTimeFormat), "%d.%m.%Y %H:%M:%S", ArrayData[Array__Time]);
    }

    client_print_color(UserId, print_team_default, "%L %L", UserId, "ZpModels__Prefix", UserId, "ZpModels__Print_Model_Info", szTimeFormat);
    return PLUGIN_HANDLED;
}

public CBasePlayer__Spawn_Post(const UserId) {
    remove_task(UserId + TaskId__UpdateModel);
    set_task(g__eSettings[Setting__TaskTime], "Task__SetUserModel", UserId + TaskId__UpdateModel);       
}

public zp_user_humanized_post(UserId, pSurvivor) {
    if(pSurvivor)
        return;
    
    remove_task(UserId + TaskId__UpdateModel);
    set_task(g__eSettings[Setting__TaskTime], "Task__SetUserModel", UserId + TaskId__UpdateModel);
}

public Task__SetUserModel(UserId) {
    UserId -= TaskId__UpdateModel;

    if(is_user_alive(UserId) && p__iModelIndex[UserId] != -1) {
        if(!zp_get_user_survivor(UserId) && !zp_get_user_nemesis(UserId) && !zp_get_user_zombie(UserId)) {
            new ArrayData[eArrayData];
            ArrayGetArray(g__aModels, p__iModelIndex[UserId], ArrayData);

            new iModelIndex = ArrayData[Array__ModelIndex];

            #if ModType == 1
                zp_set_user_model(UserId, ArrayData[Array__ModelName]);
            #else
                zp_override_user_model(UserId, ArrayData[Array__ModelName], iModelIndex);
            #endif

            set_member(UserId, m_modelIndexPlayer, iModelIndex);

            set_entvar(UserId, var_body, ArrayData[Array__ModelBody]);
            set_entvar(UserId, var_skin, ArrayData[Array__ModelSkin]);
        }
    }
}

public Func__ReadFile() {
    new szConfigFile[128];
    get_localinfo("amxx_configsdir", szConfigFile, charsmax(szConfigFile));
    strcat(szConfigFile, fmt("/%s", Config__Name), charsmax(szConfigFile));

    if(!file_exists(szConfigFile)) {
        set_fail_state("Config file <%s> not found.", szConfigFile);
    }

    new INIParser:iParser = INI_CreateParser();

    if(iParser != Invalid_INIParser) {
        INI_SetReaders(iParser, "OnKeyValue", "OnNewSection");
        INI_ParseFile(iParser, szConfigFile);
        INI_DestroyParser(iParser);
    }
    else {
        set_fail_state("Failed to create INIParser.");
    }
}

public bool: OnNewSection(INIParser: handle, const szSection[], bool:invalid_tokens, bool:close_bracket, bool:extra_tokens, curtok, any:data) {
    if(!close_bracket) {
        set_fail_state("Проверьте правильность заполнения секции [%s]", szSection);
    }

    if(strcmp(szSection, "Settings") == 0) {
        g__iSection = Section__Settings;

        return true;
    }

    if(strcmp(szSection, "Models") == 0) {
        g__iSection = Section__Models;
        g__aModels = ArrayCreate(eArrayData);

        return true;
    }

    return false;
}

public bool: OnKeyValue(INIParser:handle, const szKey[], const szValue[]) {
    switch(g__iSection) {
        case Section__None: {
            return false;
        }
        case Section__Settings: {
            if(equal(szKey, "delay_set_model")) {
                g__eSettings[Setting__TaskTime] = str_to_float(szValue);
            }
            else if(equal(szKey, "check_flags_type")) {
                g__eSettings[Setting__CheckFlagsType] = clamp(str_to_num(szValue), 0, 1);
            }
            else if(equal(szKey, "command")) {
                copy(g__eSettings[Setting__Command], charsmax(g__eSettings[Setting__Command]), szValue);
            }
        }
        case Section__Models: {
            static szBody[10], szSkin[10], szTime[32], SysTime, ArrayData[eArrayData];
            SysTime = get_systime();

            parse(szKey,
                ArrayData[Array__Key], charsmax(ArrayData[Array__Key]),
                ArrayData[Array__Value], charsmax(ArrayData[Array__Value]),
                ArrayData[Array__ModelName], charsmax(ArrayData[Array__ModelName]),
                szBody, charsmax(szBody),
                szSkin, charsmax(szSkin),
                szTime, charsmax(szTime)
            );

            if(szTime[0] != '0' && SysTime >= parse_time(szTime, "%d.%m.%Y %H:%M"))
                return true;

            ArrayData[Array__ModelBody] = str_to_num(szBody);
            ArrayData[Array__ModelSkin] = str_to_num(szSkin);
            ArrayData[Array__Time] = szTime[0] == '0' ? 0 : parse_time(szTime, "%d.%m.%Y %H:%M");

            if(file_exists(fmt("models/player/%s/%s.mdl", ArrayData[Array__ModelName], ArrayData[Array__ModelName]))) {
                ArrayData[Array__ModelIndex] = precache_model(fmt("models/player/%s/%s.mdl", ArrayData[Array__ModelName], ArrayData[Array__ModelName]));
            }
            else {
                set_fail_state("Zombie Plague Skins - Bad load model: %s", ArrayData[Array__ModelName]);
            }

            ArrayPushArray(g__aModels, ArrayData);
        }
    }

    return true;
}

public plugin_natives() {
    set_native_filter("Native__Filter");
}

public Native__Filter(const szName[]) {
    if(equal(szName, "cmsapi_get_user_services"))
        return PLUGIN_HANDLED;

    return PLUGIN_CONTINUE;
}

stock CheckPlayerFlags(const UserId, const szFlags[], const Type) {
    switch(Type) {
        case 0: {
            return bool:(get_user_flags(UserId) & read_flags(szFlags) == read_flags(szFlags));
        }
        case 1: {
            return bool:(get_user_flags(UserId) & read_flags(szFlags));
        }
    }

    return false;
}

stock RegisterAllCmd(const szCmd[], const szFunction[]) {
    register_clcmd(fmt("say /%s", szCmd), szFunction);
    register_clcmd(fmt("say_team /%s", szCmd), szFunction);
    register_clcmd(szCmd, szFunction);
}