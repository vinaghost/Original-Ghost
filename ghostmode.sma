#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fun>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <engine>
#include <dhudmessage>
#include <colorchat>

#define PLUGIN "Original Ghost"
#define VERSION "1.3"
#define AUTHOR "S.M & VINAGOHST"

#define V_MODEL "models/v_blurred_knife.mdl"
#define C4_MODEL "models/v_blurred_c4.mdl"
#define FLASH_MODEL "models/v_blurred_flashbang.mdl"

#define SPEEDTASK 1
#define m_iDefaultItems 120 //default weapon offset

#tryinclude <cstrike_pdatas> //down cai nay ve compile ez

#if !defined _cbaseentity_included
#assert Cstrike Pdatas and Offsets library required! Read the below instructions:   \
1. Download it at forums.alliedmods.net/showpost.php?p=1712101#post1712101   \
2. Put it into amxmodx/scripting/include/ folder   \
3. Compile this plugin locally, details: wiki.amxmodx.org/index.php/Compiling_Plugins_%28AMX_Mod_X%29   \
4. Install compiled plugin, details: wiki.amxmodx.org/index.php/Configuring_AMX_Mod_X#Installing
#endif

#define Get_BitVar(%1,%2)		(%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2)		(%1 |= (1 << (%2 & 31)));
#define UnSet_BitVar(%1,%2)		(%1 &= ~(1 << (%2 & 31)));

#define EXPLOSION_TIME 5.0

new const c4_drop_sound[] = "og/suicidal.wav"
new mdl_gib_flesh, mdl_gib_head, mdl_gib_legbone
new mdl_gib_lung, mdl_gib_meat, mdl_gib_spine
new spr_blood_drop, spr_blood_spray
#define BLOOD_COLOR_RED		247
new const exp_spr[] = "sprites/zerogxplode.spr"
new exp_spr_id
/*#define EXPLOSION_RADIUS 300.0
#define MAX_DAMAGE 100.0*/

new g_ghost//[33] //player co phai ghost ko (bool)
new g_invis//[33] //player co dang tang hinh ko(bool)
//new const m_rgpPlayerItems_CWeaponBox[6] = {34,35,...}
//new g_c4[33] //quen cmnr, thoi de day

new g_deadlystab//[33] //player co deadly stab ko(bool)
new g_tho //player co tat tho chua ?
new g_is //playerco lam is khong ?
new g_speed // player co speed boost chua ?

new g_antiflash //player co anti fl khong ?
new g_thorn //player co giap gai khong ?

new og_ghosthp, og_ghostarmor, og_invisdamerate, og_visdamerate, og_ghostspeed, og_nadesdamerate, og_deathlyrate,
og_maplight, og_tho,  og_tho_min, og_tho_max, og_ghostspeed_boost,og_is, og_is_radius, og_is_maxdmg;

new const Ham:Ham_Player_ResetMaxSpeed = Ham_Item_PreFrame;


#define WEAPON_SUIT 31
#define WEAPON_SUIT_BIT 1<<WEAPON_SUIT; // vai cai offset

new g_bConnectedPlayers[33 char] //quen cmnr
new bool:check = false;

new const sound_breath[] = "og/breath_2.wav"

new g_msgid_ScreenFade, g_PlayerFlasher
const PEV_NADE_TYPE = pev_flTimeStepSound
const NADE_TYPE_FLASH = 3333

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	//register_event("CurWeapon", "CurWeapon", "be", "1=1") //check weapon, cai nay co the cai tien = Ham_ItemDeploy
	
	//register_event("ResetHUD", "newround", "b")
	register_event("HLTV", "newround", "a", "1=0", "2=0");
	register_event("TextMsg","event_showbuymessage","b","2=#Terrorist_cant_buy");
	register_message(get_user_msgid("TextMsg") ,"message_TextMsg")
	
	//register_logevent("logevent_round_start", 2, "1=Round_Start")  
	
	RegisterHam(Ham_Spawn, "player", "HamSpawn", 1) //block default wpn at spawn
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage") //xu? li' ve` damage
	
	RegisterHam(Ham_Touch, "armoury_entity", "FwdHamPickupWeapon")
	register_touch("weapon_shield", "player", "OnPlayerTouchShield");
	RegisterHam(Ham_Touch, "weaponbox", "FwdHamPickupWeapon") //block ghost pick weapon
	RegisterHam(Ham_Think, "grenade", "fw_ThinkGrenade")
	
	//RegisterHam(Ham_Item_Deploy, "weapon_knife", "fwReplaceModels", 1);
	//RegisterHam(Ham_Item_Deploy, "weapon_c4", "fwReplaceModels", 1);
	RegisterHam(Ham_Player_ResetMaxSpeed, "player", "CBasePlayer_ResetMaxSpeed", 1 );
	
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_CmdStart, "FMCmdStart")
	
	register_clcmd("say /menu", "show_mainMenu");
	register_clcmd("chooseteam", "show_mainMenu", 0);
	register_clcmd("drop", "handle_drop")
	
	og_ghosthp = register_cvar("og_ghost_hp", "50");
	og_ghostarmor = register_cvar("og_ghost_armor", "200");
	og_invisdamerate = register_cvar("og_ghost_invisdamerate", "0.5");
	og_visdamerate = register_cvar("og_ghost_visdamerate", "1.0");
	og_ghostspeed = register_cvar("og_ghost_speed", "500");
	og_nadesdamerate = register_cvar("og_nadesdamerate", "0.5");
	og_maplight = register_cvar("og_ghost_light", "d");
	og_deathlyrate = register_cvar("og_ghost_deathlyrate", "2.0");
	og_tho = register_cvar("og_ghost_tho", "0");
	og_is = register_cvar("og_ghost_is", "0");
	og_tho_min = register_cvar("og_ghost_tho_min", "4.0");
	og_tho_max = register_cvar("og_ghost_tho_max", "7.0");
	og_is_radius = register_cvar("og_ghost_is_radius", "500.0");
	og_is_maxdmg = register_cvar("og_ghost_is_maxdmg", "300.0");
	og_ghostspeed_boost = register_cvar("og_ghost_speed_boost", "800");
	
	set_msg_block(get_user_msgid("ShadowIdx"), BLOCK_SET) // remove shadow
	
	g_msgid_ScreenFade = get_user_msgid("ScreenFade")
	
	register_message(g_msgid_ScreenFade, "message_screenfade");
	
	server_cmd("mp_roundtime 2.5")
	server_cmd("mp_buytime 0.1")
	server_cmd("mp_freezetime 3");
	server_cmd("mp_playerid 1");
}
public plugin_precache()
{
	disable_buyzone();
	
	precache_model(V_MODEL)
	precache_model(C4_MODEL)
	precache_model(FLASH_MODEL);
	//precache_model("models/player/ghost1/ghost1.mdl")
	
	precache_sound(sound_breath)
	
	precache_model(exp_spr)
	precache_sound(c4_drop_sound)
	
	mdl_gib_flesh = precache_model("models/Fleshgibs.mdl")
	mdl_gib_meat = precache_model("models/GIB_B_Gib.mdl")
	mdl_gib_head = precache_model("models/GIB_Skull.mdl")
	mdl_gib_spine = precache_model("models/GIB_B_Bone.mdl")
	mdl_gib_lung = precache_model("models/GIB_Lung.mdl")
	mdl_gib_legbone = precache_model("models/GIB_Legbone.mdl")
	spr_blood_drop = precache_model("sprites/blood.spr")
	spr_blood_spray = precache_model("sprites/bloodspray.spr")
}

public FMCmdStart(id, uc_handle, randseed) //~ prethink ~ postthink
{	
	if(is_user_alive(id))
	{
		if(Get_BitVar(g_ghost,id)) 
		{
			
			static Float: fmove //forward move speed
			static Float: smove //side move speed
			get_uc(uc_handle, UC_ForwardMove, fmove)
			get_uc(uc_handle, UC_SideMove, smove)
			static Float: maxspeed
			pev(id, pev_maxspeed, maxspeed)
			static Float: walkspeed
			walkspeed = (0.52 * maxspeed)
			fmove = floatabs(fmove)
			smove = floatabs(smove)
			
			if(fmove <= walkspeed && smove <= walkspeed) //player is walking
			{
				//set_task(0.1, "task_walking", id)
				set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderTransTexture, 0)
				set_pev(id, pev_viewmodel, 0)
				Set_BitVar(g_invis,id)
				if( get_pcvar_num(og_tho) )
				{
					if( !Get_BitVar(g_tho,id) )
					{
						if( !task_exists(id + 1337) ) 
							set_task( random_float(get_pcvar_float(og_tho_min), get_pcvar_float(og_tho_max) ), "tho_ing", id + 1337)
					}
				}
			}
			else //player is running
			{
				//set_task(0.1, "task_running", id)
				set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderTransTexture, 50)
				new weapon, clip, ammo
				weapon = get_user_weapon(id, clip, ammo)
				if(weapon == CSW_C4)
				{
					entity_set_string(id, EV_SZ_viewmodel, C4_MODEL)
				}
				else if(weapon == CSW_KNIFE)
				{
					entity_set_string(id, EV_SZ_viewmodel, V_MODEL)
				}
				else if(weapon == CSW_FLASHBANG)
				{
					entity_set_string(id, EV_SZ_viewmodel, FLASH_MODEL);
				}
				
				UnSet_BitVar(g_invis,id)
				
				if( get_pcvar_num(og_tho) )
				{
					if(!Get_BitVar(g_tho, id) )
					{
						if( task_exists(id + 1337) ) remove_task(id + 1337)
					}
					
				}
			}
		}
		/*else if(cs_get_user_team(id) == CS_TEAM_CT) {
		set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderNormal, 0)
		UnSet_BitVar(g_invis,id)*/
	}
}

public tho_ing(id) 
{
	if( get_pcvar_num(og_tho) )
	{
		id -= 1337;
		
		if (!is_user_alive(id) || !Get_BitVar(g_ghost,id)) {
			return;
		}
		
		new Float:fVolume = 0.4
		
		emit_sound(id, CHAN_WEAPON, sound_breath , fVolume, ATTN_NORM, 0, 94);
	}
}
// Set ghost speed to maxspeed again when changing weapon 
public CBasePlayer_ResetMaxSpeed (const Player){
	if (is_user_alive(Player))
	{	
		new Float:MaxSpeed = get_user_maxspeed(Player);
		if (MaxSpeed != 1.0) {
			if(Get_BitVar(g_ghost,Player))
			{
				if( Get_BitVar(g_speed, Player)) 
					set_user_maxspeed( Player, get_pcvar_float(og_ghostspeed_boost));
				else 
					set_user_maxspeed( Player, get_pcvar_float(og_ghostspeed));
			}
			else 
				set_user_maxspeed(Player, 250.0);
		}
	}
	
}

// Change hand model of ghost: hide ghost's hand when walking and show it when running
/*
public fwReplaceModels(ent) {
	new id = get_pdata_cbase(ent, 41, 4);
	new weapon, clip, ammo;
	weapon = get_user_weapon(id, clip, ammo);
	
	if(cs_get_user_team(id) == CS_TEAM_T) {
		if(weapon == CSW_KNIFE)
		{
			entity_set_string(id, EV_SZ_viewmodel, V_MODEL)
		}
		else if(weapon == CSW_C4)
		{
			entity_set_string(id, EV_SZ_viewmodel, C4_MODEL)	
		}
		else if(weapon == CSW_FLASHBANG)
		{
			entity_set_string(id, EV_SZ_viewmodel, FLASH_MODEL);
		}
	}
}
*/
// Block default weapon
public HamSpawn(id){
	UnSet_BitVar(g_deadlystab,id)
	UnSet_BitVar(g_invis,id)
	UnSet_BitVar(g_tho,id)
	UnSet_BitVar(g_is,id)
	
	UnSet_BitVar(g_antiflash,id)
	UnSet_BitVar(g_thorn,id)
	
	//set_user_godmode(id)
	
	if( is_user_alive(id) ) 
	{
		if(get_user_gravity(id) != 1.0 )
			set_user_gravity(id, 1.0);
		if( get_user_footsteps(id) ) 
			set_user_footsteps(id, 0)
		if( get_user_godmode(id) ) 
			set_user_godmode(id, 0)
		
		if(cs_get_user_team(id) == CS_TEAM_T) {
			
			strip_user_weapons(id);
			
			give_item(id, "weapon_knife");
			give_item(id, "weapon_flashbang");
			give_item(id, "weapon_flashbang");
			
			set_user_health(id, get_pcvar_num(og_ghosthp));
			
			cs_set_user_armor(id, get_pcvar_num(og_ghostarmor),CS_ARMOR_VESTHELM)
			;
			Set_BitVar(g_ghost,id)
			
			
			set_task(get_cvar_float("mp_freezetime"), "set_speed", id);
		}
		else if (cs_get_user_team(id) == CS_TEAM_CT)
		{
			set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderNormal, 0)
			// set_user_health(id, 100); khong can vi mac dinh da 100 roi
			cs_set_user_armor(id, 100 ,CS_ARMOR_VESTHELM);
			UnSet_BitVar(g_ghost,id)
		}
	}
}

public set_speed(id){
	set_user_maxspeed(id, get_pcvar_float(og_ghostspeed));
}

public newround()
{
	new light[1];
	get_pcvar_string(og_maplight, light, 1);
	set_lights(light[0]);
}
public fw_TakeDamage(victim, inflictor, attacker, Float:damage)
{
	if(victim != attacker && is_user_connected(attacker))
	{
		//if(cs_get_user_team(attacker) == CS_TEAM_T)
		if( Get_BitVar(g_ghost, attacker) ) // co sao khong sai ?
		{
			if(get_user_weapon(attacker) == CSW_KNIFE)
			{
				new Float: dmg
				if(Get_BitVar(g_deadlystab,attacker))
				{
					dmg =  damage * get_pcvar_float(og_deathlyrate); //x2 damage: // Stab: 1Hit // Slash: 2Hit
					
				}
				else
				{
					if(Get_BitVar(g_invis,attacker))
					{
						dmg = damage * get_pcvar_float(og_invisdamerate); //0.5x damage
					}
					else
					{
						dmg = damage * get_pcvar_float(og_visdamerate); //normal damage
					}
				}
				
				SetHamParamFloat(4, dmg)
				
				if( Get_BitVar(g_thorn, victim) )
				{
					dmg = (dmg/100)*60
					ExecuteHamB(Ham_TakeDamage, attacker,  victim,  victim, dmg, DMG_SHOCK)
				}
				
			}
			// khong hieu cho lam ghost nem he ma trong shop lai khong ban ?
			else if(get_user_weapon(attacker) == CSW_HEGRENADE)
			{
				SetHamParamFloat(4, damage * get_pcvar_float(og_nadesdamerate));
			}
		}
		
		else 
		{
			if(get_user_weapon(attacker) == CSW_KNIFE)
			{
				SetHamParamFloat(4, damage * get_pcvar_float(og_visdamerate) * 0.6);
			}
		}
	}
	
	//return HAM_HANDLED
}
public FwdHamPickupWeapon(ent, id) //block wpn pickup
{
	
	if(is_user_alive(id) )
	{
		if (Get_BitVar(g_ghost, id) )
		{
			if( Get_BitVar(g_is, id) )
				return HAM_SUPERCEDE
			else if(GetWeaponBoxWeaponType(ent) != CSW_C4) 
				return HAM_SUPERCEDE
		}
	}
	
	return HAM_IGNORED
}
public OnPlayerTouchShield(ent, id) 
{ 
	if( Get_BitVar(g_ghost,id))
		return PLUGIN_HANDLED
	
	return PLUGIN_CONTINUE
} 		
public buybackHandler(id)
{
	if(Get_BitVar(g_ghost, id))
	{
		if(!is_user_alive(id))
		{
			new playerMoney = cs_get_user_money(id);
			
			if(playerMoney >= 15000)
			{
				ExecuteHamB(Ham_CS_RoundRespawn, id)
				cs_set_user_money(id, playerMoney - 15000, 1);
				new name[32]
				get_user_name(id, name, charsmax(name));
				ColorChat(0, GREEN, "[O.G] ^x03%s^x01 đã hồi sinh!",name);
			}
			else client_print(id, print_chat, "[O.G] Không đủ tiền!")
		}
		else client_print(id, print_chat, "[O.G] Chỉ có thể khi đã chết!")
	}
	else client_print(id, print_chat, "[O.G] Chỉ được hồi sinh khi là ghost!")
	
	return PLUGIN_HANDLED
}
public show_mainMenu(id) {
	if (cs_get_user_team(id) == CS_TEAM_UNASSIGNED || cs_get_user_team(id) == CS_TEAM_SPECTATOR || check){
		check = false;
		return PLUGIN_CONTINUE
	}
	else {
		new mainMenu = menu_create("[O.G] Menu", "menu_mainHandler");
		menu_additem(mainMenu, "Mua đồ", "1", 0);
		menu_additem(mainMenu, "Chọn bên", "2", 0);
		menu_additem(mainMenu, "Hồi sinh - 15000$", "3", 0);
		menu_setprop(mainMenu, MPROP_EXIT, MEXIT_ALL);
		menu_display(id, mainMenu, 0)
		
		return PLUGIN_HANDLED 
		
	}
	return PLUGIN_HANDLED
}

public menu_mainHandler(id, menu, item) {
	switch(item) {
		case 0: 
		{
			if(Get_BitVar(g_ghost, id)) 
				show_shopMenu(id);
			else 
				show_shopMenu_ct(id);
		}
		case 1:
		{
			check = true;
			client_cmd(id, "chooseteam");
		}	
		
		case 2: buybackHandler(id);
		}
}
public show_shopMenu_ct(id)
{	
	if(is_user_alive(id))
	{
		
		new menu = menu_create("[O.G] F.R.I.S Mini Shop", "miniShop_handler_ct")
		menu_additem(menu, "Anti FlashBang - 3000$");
		menu_additem(menu, "Giáp điện - 5000$");
		menu_additem(menu, "Cứu thương - 3000$");
		menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
		menu_display(id, menu, 0)
	}
	else client_print(id, print_center, "[O.G] Chỉ có thể mua khi sống.");
	
	return PLUGIN_HANDLED
}
public miniShop_handler_ct(id, menu, item)
{
	if(is_user_alive(id))
	{	
		new money = cs_get_user_money(id);
		switch(item)
		{
			
			case 0:
			{
				
				//new curMoney = cs_get_user_money(id); the nao ma chi co moi case 0 la sai ma khong phai la tat ca ?
				if ( !Get_BitVar(g_antiflash,id )) 
				{
					if(money > 3000) {
						Set_BitVar(g_antiflash, id) 
						client_print(id, print_chat, "[O.G] Đã mua kính chống Fl'");
						cs_set_user_money(id, money - 3000, 1);
					}
					else
					{
						client_print(id, print_chat, "[O.G] Không đủ tiền.");
					}
				}
				else 
					client_print(id, print_chat, "[O.G] Đã mua rồi");
			}
			case 1:
			{
				if ( !Get_BitVar(g_thorn,id )) 
				{
					if(money >= 5000)
					{
						
						Set_BitVar(g_thorn,id)
						cs_set_user_money(id, money - 5000)
						client_print(id, print_chat, "[O.G] Đã mua giáp điện.")
						client_print(id, print_chat, "[O.G] Giáp điện phản lại 60% dmg của ghost.")
					}
					
					else
						client_print(id, print_chat, "[O.G] Không đủ tiền.")
					
				}
				else 
					client_print(id, print_chat, "[O.G] Đã mua rồi");
			}
			
			case 2:
			{
				if(money >= 3000)
				{
					
					hoimaughe(id)
					cs_set_user_money(id, money - 3000)
					client_print(id, print_chat, "[O.G] Bắt đầu sơ cứu vết thương.")
					client_print(id, print_chat, "[O.G] 25HP/s cho tới khi đầy máu ")
				}
				
				else
					client_print(id, print_chat, "[O.G] Không đủ tiền.")
			}
			/*case 3:
		{
			if(money >= 7500)
			{
				
				cs_set_user_money(id, money - 7500)
				client_print(id, print_chat, "[O.G] .")
				set_user_footsteps(id, 1)
			}
			else
			{
				client_print(id, print_chat, "[O.G] Không đủ tiền..")
			}
			
		}
		case 4:
		{
			
			if(money >= 7500)
			{
				Set_BitVar(g_speed,id)
				set_user_maxspeed(id, get_pcvar_float(og_ghostspeed_boost)) 
				cs_set_user_money(id, money - 7500)
				client_print(id, print_chat, "[O.G] Chay nhanh nhen da duoc kich hoat.")
			}
			else
			{
				client_print(id, print_chat, "[O.G] Không đủ tiền..")
			}
			
		}
		case 5:
		{
			if( get_pcvar_num(og_tho) )
			{
				if(money >= 7500)
				{
					Set_BitVar(g_tho,id)
					cs_set_user_money(id, money - 7500)
					client_print(id, print_chat, "[O.G] Tat tho da duoc kich hoat.")
				}
				else
				{
					client_print(id, print_chat, "[O.G] Không đủ tiền..")
				}
			}
			else 
				client_print(id, print_chat, "[O.G] Khong tho khoi tat tho.")
			}
			case 6:
			{
				if(money >= 9000)
				{
					set_user_gravity(id, 0.5)
					cs_set_user_money(id, money - 9000)
					client_print(id, print_chat, "[O.G] Nhay cao da duoc kich hoat.")
				}
				else
				{
					client_print(id, print_chat, "[O.G] Không đủ tiền..")
				}
			}
			
			case 7:
			{
				if(money >= 16000)
				{
					Set_BitVar(g_deadlystab,id)
					cs_set_user_money(id, money - 16000)
					client_print(id, print_chat, "[O.G] Vu khi duoc tang cuong sat thuong.")
					new name[32]
					get_user_name(id, name, charsmax(name));
					ColorChat(0, GREEN, "[O.G] ^x03%s^x01 da kich hoat x2 sat thuong!",name);
				}
				else
				{
					client_print(id, print_chat, "[O.G] Không đủ tiền..")
				}
			}
			case 8:
			{
				if( get_pcvar_num(og_is) )
				{
					if(money >= 12000)
					{
						new bomb = fm_find_ent_by_class(-1, "weapon_c4")
						if (bomb) 
						{
							if( id == pev(bomb, pev_owner) )
							{
								engclient_cmd(0, "drop", "weapon_c4")
							}
						}
						
						Set_BitVar(g_is, id)
						give_item(id, "weapon_c4")
						cs_set_user_plant(id, 0, 0)
						cs_set_user_money(id, money - 12000)
						client_print(id, print_chat, "[O.G] Bom tu sat da duoc them vao tui do.")
						client_print(id, print_chat, "[O.G] Cam C4 roi nhan G de danh bom")
						new name[32]
						get_user_name(id, name, charsmax(name));
						ColorChat(0, GREEN, "[O.G] ^x03%s^x01 chuan bi danh bom lieu chet!",name);
					}
					else
					{
						client_print(id, print_chat, "[O.G] Không đủ tiền..")
					}
				}
				else 
					client_print(id, print_chat, "[O.G] IS da bi tat.")
			}*/
		}
	}
	menu_destroy(menu)
}
public show_shopMenu(id)
{	
	if(is_user_alive(id))
	{
		
		new menu = menu_create("[O.G] Ghost Mini Shop", "miniShop_handler")
		menu_additem(menu, "Flashbang - 8000$");
		menu_additem(menu, "25 HP - 2000$");
		menu_additem(menu, "50 HP - 4000$");
		menu_additem(menu, "Chạy nhẹ nhàng - 7500$");
		menu_additem(menu, "Chạy nhanh nhẹn - 7500$");
		menu_additem(menu, "Tắt thở - 7500$");
		menu_additem(menu, "Nhảy cao - 9000$");
		menu_additem(menu, "x2 damage - 16000$")
		menu_additem(menu, "IS - 12000$")
		menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
		menu_display(id, menu, 0)
		
	}
	else client_print(id, print_center, "[O.G] Chỉ có thể mua khi còn sống.");
	
	return PLUGIN_HANDLED
}
public miniShop_handler(id, menu, item)
{
	if(is_user_alive(id))
	{	
		new money = cs_get_user_money(id);
		switch(item)
		{
			
			case 0:
			{
				
				//new curMoney = cs_get_user_money(id); the nao ma chi co moi case 0 la sai ma khong phai la tat ca ?
				if(money > 8000) {
					give_item(id, "weapon_flashbang");
					client_print(id, print_chat, "[O.G] Đã mua 1 quả flashbang");
					cs_set_user_money(id, money - 8000, 1);
				}
				else
				{
					client_print(id, print_chat, "[O.G] Không đủ tiền.");
				}
			}
			case 1:
			{
				if( get_user_health(id) + 25 <= 200 )
				{
					if(money >= 2000)
					{
						
						set_user_health(id, get_user_health(id) + 25)
						cs_set_user_money(id, money - 2000)
						client_print(id, print_chat, "[O.G] Đã tăng thêm 25HP")
					}
					
					else
						client_print(id, print_chat, "[O.G] Không đủ tiền..")
				}
				else 
					client_print(id, print_chat, "[O.G] Máu tối đa là 200.")
			}
			case 2:
			{
				if( get_user_health(id) + 50 <= 200 )
				{
					if(money >= 4000)
					{
						
						set_user_health(id, get_user_health(id) + 50)
						cs_set_user_money(id, money - 4000)
						client_print(id, print_chat, "[O.G] Đã tăng thêm 50HP.")
					}
					
					else
						client_print(id, print_chat, "[O.G] Không đủ tiền.")
				}
				else 
					client_print(id, print_chat, "[O.G] Máu tối đa là 200.")
			}
			case 3:
			{
				if( !get_user_footsteps(id)) 
				{
					if(money >= 7500)
					{
						
						cs_set_user_money(id, money - 7500)
						client_print(id, print_chat, "[O.G] Chạy nhẹ nhàng được kích hoạt.")
						set_user_footsteps(id, 1)
					}
					else
					{
						client_print(id, print_chat, "[O.G] Không đủ tiền.")
					}
				}
				else 
					client_print(id, print_chat, "[O.G] Đã mua rồi.")
				
			}
			case 4:
			{
				if( !Get_BitVar(g_speed, id) )
				{
					if(money >= 7500)
					{
						Set_BitVar(g_speed,id)
						set_user_maxspeed(id, get_pcvar_float(og_ghostspeed_boost)) 
						cs_set_user_money(id, money - 7500)
						client_print(id, print_chat, "[O.G] Chạy nhanh nhẹn được kích hoạt.")
					}
					else
					{
						client_print(id, print_chat, "[O.G] Không đủ tiền.")
					}
				}
				else 
					client_print(id, print_chat, "[O.G] Đã mua rồi.")
				
			}
			case 5:
			{
				if( get_pcvar_num(og_tho) )
				{
					if( !Get_BitVar(g_tho,id ))
					{
						if(money >= 7500)
						{
							Set_BitVar(g_tho,id)
							cs_set_user_money(id, money - 7500)
							client_print(id, print_chat, "[O.G] Tắt thở được kích hoạt.")
						}
						else
						{
							client_print(id, print_chat, "[O.G] Không đủ tiền.")
						}
					}
					else 
						client_print(id, print_chat, "[O.G] Đã mua rồi.")
				}
				else 
					client_print(id, print_chat, "[O.G] Không thở khỏi tắt thở.")
			}
			case 6:
			{
				if( get_user_gravity(id) == 1.0) 
				{
					if(money >= 9000)
					{
						set_user_gravity(id, 0.5)
						cs_set_user_money(id, money - 9000)
						client_print(id, print_chat, "[O.G] Nhảy cao được kích hoạt.")
					}
					else
					{
						client_print(id, print_chat, "[O.G] Không đủ tiền.")
					}
				}
				else 
					client_print(id, print_chat, "[O.G] Đã mua rồi.")
			}
			
			case 7:
			{
				if( !Get_BitVar(g_deadlystab, id))
				{
					if(money >= 16000)
					{
						Set_BitVar(g_deadlystab,id)
						cs_set_user_money(id, money - 16000)
						client_print(id, print_chat, "[O.G] Vũ khi được tăng cường sát thương.")
						new name[32]
						get_user_name(id, name, charsmax(name));
						ColorChat(0, GREEN, "[O.G] ^x03%s^x01 đã kích hoạt x2 sát thương!",name);
					}
					else
					{
						client_print(id, print_chat, "[O.G] Không đủ tiền.")
					}
				}
				else 
					client_print(id, print_chat, "[O.G] Đã mua rồi.")
			}
			case 8:
			{
				if( get_pcvar_num(og_is) )
				{
					if( !Get_BitVar(g_is, id) ) 
					{
						if(money >= 12000)
						{
							new bomb = fm_find_ent_by_class(-1, "weapon_c4")
							if (bomb) 
							{
								if( id == pev(bomb, pev_owner) )
								{
									engclient_cmd(0, "drop", "weapon_c4")
								}
							}
							
							Set_BitVar(g_is, id)
							give_item(id, "weapon_c4")
							cs_set_user_plant(id, 0, 0)
							cs_set_user_money(id, money - 12000)
							client_print(id, print_chat, "[O.G] Bom tự sát đã được thêm vào túi đồ.")
							client_print(id, print_chat, "[O.G] Cầm C4 rồi nhấn G để đánh bom tự sát")
							new name[32]
							get_user_name(id, name, charsmax(name));
							ColorChat(0, GREEN, "[O.G] ^x03%s^x01 đã chuẩn bị 1 quả bom tự sát!",name);
						}
						else
						{
							client_print(id, print_chat, "[O.G] Không đủ tiền.")
						}
					}
					else 
						client_print(id, print_chat, "[O.G] Đã mua rồi.")
				}
				else 
					client_print(id, print_chat, "[O.G] IS đã bị tắt.")
			}
		}
	}
	menu_destroy(menu)
}
//tro gi day ay nhi ?
public client_connect(id)
{
	g_bConnectedPlayers[id] = false
}
public client_putinserver(id)
{
	g_bConnectedPlayers[id] = true
}
//tro gi day ay nhi ?

public event_showbuymessage(id){
	client_print(id,print_center,"[O.G] Ấn M để vào cửa hàng!");
}
public disable_buyzone() {
	new ent = find_ent_by_class(-1,"info_map_parameters");
	
	// if we couldn't find one, make our own
	if(!ent) 
		ent = create_entity("info_map_parameters");
	
	// disable buying for TS team
	DispatchKeyValue(ent,"buying","1");
	DispatchSpawn(ent);
}

GetWeaponBoxWeaponType(ent) {
	new weapon
	for(new i = 1; i <= 5; i++)
	{
		weapon = get_pdata_cbase(ent, m_rgpPlayerItems_CWeaponBox[i], XO_CWEAPONBOX)
		if(weapon > 0)
		{
			return cs_get_weapon_id(weapon)
		}
	}
	return 0
}
public message_TextMsg( const MsgId, const MsgDest, const MsgEntity )
{    
	static message[32]
	get_msg_arg_string(2, message, charsmax(message))
	
	if(equal(message, "#Terrorists_Win"))
	{
		set_msg_arg_string(2, "Ghost Team Win!!!");
	}
	else if(equal(message, "#CTs_Win"))
	{
		set_msg_arg_string(2, "F.R.I.S Team Win!!!")
	}
}
public handle_drop(id)
{
	if(Get_BitVar(g_is, id) )
	{
		if( is_user_alive(id))
		{
			if( get_user_weapon(id) == CSW_C4  )
			{
				UnSet_BitVar(g_is,id)
				
				do_drop_c4(id)
				ham_strip_user_weapon(id, CSW_C4)
				set_user_godmode(id, 1)
				
				return PLUGIN_HANDLED
			}
		}
		
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}

public do_drop_c4(id)
{
	new Name[64]
	get_user_name(id, Name, sizeof(Name))
	
	// Hud
	set_dhudmessage(255, 0, 0, -1.0, 0.25, 1, 6.0, 6.0)
	show_dhudmessage(0, "%s đã kích hoạt bom! ^nCHẠY NGAY ĐI!!!!!", Name)
	
	fm_set_rendering(id, kRenderFxGlowShell, 255, 0, 0, kRenderTransColor, 50)
	client_cmd(0, "spk ^"%s^"", c4_drop_sound)
	
	set_task(EXPLOSION_TIME, "do_explosion", id)
}
public do_explosion(id)
{	
	new Origin[3]
	get_user_origin(id, Origin, 0)
	set_user_godmode(id, 0)
	ExecuteHamB(Ham_Killed, id, id, 0)
	
	//explosion_effect(id)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	write_coord(Origin[0])
	write_coord(Origin[1])
	write_coord(Origin[2])
	write_short(exp_spr_id)
	write_byte(30)
	write_byte(30)
	write_byte(0)  
	message_end()
	
	fx_gib_explode(Origin, Origin)
	
	checking_takedamage(id)
	
}

public fx_gib_explode(origin[3], origin2[3]) {
	new flesh[2]
	flesh[0] = mdl_gib_flesh
	flesh[1] = mdl_gib_meat
	
	new mult, gibtime = 200 //20 seconds
	mult = 80
	
	new rDistance = get_distance(origin,origin2) ? get_distance(origin,origin2) : 1
	new rX = ((origin[0]-origin2[0]) * mult) / rDistance
	new rY = ((origin[1]-origin2[1]) * mult) / rDistance
	new rZ = ((origin[2]-origin2[2]) * mult) / rDistance
	new rXm = rX >= 0 ? 1 : -1
	new rYm = rY >= 0 ? 1 : -1
	new rZm = rZ >= 0 ? 1 : -1
	
	// Gib explosions
	
	// Head
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte(TE_MODEL)
	write_coord(origin[0])
	write_coord(origin[1])
	write_coord(origin[2]+40)
	write_coord(rX + (rXm * random_num(0,80)))
	write_coord(rY + (rYm * random_num(0,80)))
	write_coord(rZ + (rZm * random_num(80,200)))
	write_angle(random_num(0,360))
	write_short(mdl_gib_head)
	write_byte(0) // bounce
	write_byte(gibtime) // life
	message_end()
	
	// Parts
	for(new i = 0; i < 4; i++)
	{
		message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
		write_byte(TE_MODEL)
		write_coord(origin[0])
		write_coord(origin[1])
		write_coord(origin[2])
		write_coord(rX + (rXm * random_num(0,80)))
		write_coord(rY + (rYm * random_num(0,80)))
		write_coord(rZ + (rZm * random_num(80,200)))
		write_angle(random_num(0,360))
		write_short(flesh[random_num(0,1)])
		write_byte(0) // bounce
		write_byte(gibtime) // life
		message_end()
	}
	
	// Spine
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte(TE_MODEL)
	write_coord(origin[0])
	write_coord(origin[1])
	write_coord(origin[2]+30)
	write_coord(rX + (rXm * random_num(0,80)))
	write_coord(rY + (rYm * random_num(0,80)))
	write_coord(rZ + (rZm * random_num(80,200)))
	write_angle(random_num(0,360))
	write_short(mdl_gib_spine)
	write_byte(0) // bounce
	write_byte(gibtime) // life
	message_end()
	
	// Lung
	for(new i = 0; i <= 1; i++) 
	{
		message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
		write_byte(TE_MODEL)
		write_coord(origin[0])
		write_coord(origin[1])
		write_coord(origin[2]+10)
		write_coord(rX + (rXm * random_num(0,80)))
		write_coord(rY + (rYm * random_num(0,80)))
		write_coord(rZ + (rZm * random_num(80,200)))
		write_angle(random_num(0,360))
		write_short(mdl_gib_lung)
		write_byte(0) // bounce
		write_byte(gibtime) // life
		message_end()
	}
	
	//Legs
	for(new i = 0; i <= 1; i++) 
	{
		message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
		write_byte(TE_MODEL)
		write_coord(origin[0])
		write_coord(origin[1])
		write_coord(origin[2]-10)
		write_coord(rX + (rXm * random_num(0,80)))
		write_coord(rY + (rYm * random_num(0,80)))
		write_coord(rZ + (rZm * random_num(80,200)))
		write_angle(random_num(0,360))
		write_short(mdl_gib_legbone)
		write_byte(0) // bounce
		write_byte(gibtime) // life
		message_end()
	}
	
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte(TE_BLOODSPRITE)
	write_coord(origin[0])
	write_coord(origin[1])
	write_coord(origin[2]+20)
	write_short(spr_blood_spray)
	write_short(spr_blood_drop)
	write_byte(BLOOD_COLOR_RED) // color index
	write_byte(10) // size
	message_end()
}
public checking_takedamage(id)
{
	new iVictim, Float:Origin[3], Float:Damage, Float:Range
	
	iVictim = -1
	pev(id, pev_origin, Origin)
	new name[33]
	get_user_name(id, name, charsmax(name))
	new Float:dist = get_pcvar_float(og_is_radius)
	new Float:max_dmg = get_pcvar_float(og_is_maxdmg)
	
	
	while( (iVictim = find_ent_in_sphere(iVictim, Origin,	dist) )  != 0 )
	{
		if(is_user_alive(iVictim) )
		{
			if( !Get_BitVar(g_ghost, iVictim))
			{
				Range = entity_range(id, iVictim)
				
				if( Range < dist/4 )
					Damage = max_dmg
				else if (Range> dist/4 && Range < dist/2)
					Damage = max_dmg/2
				else if (Range> dist/2 && Range < dist)
					Damage = max_dmg/4
				else 
					Damage = max_dmg/8
				
				if( get_user_health(id) - floatround(Damage) <  0)
				{
					new v_name[33]
					client_print(0, print_chat, "%s đã chết trong vụ đánh bom liều chết của %s", v_name, name)
				}
				
				ExecuteHam(Ham_TakeDamage, iVictim, 0, id, Damage, DMG_BLAST)
				
				
				
			}
		}
	}
}
public hoimaughe(id) {
	
	if( is_user_alive(id) ) 
	{
		new hp = get_user_health(id)
		if(  hp  < 100)
		{
			set_user_health(id, hp + 25)
			
			if( hp +25 > 100)
				set_user_health(id, 100)
			else 
				set_task(1.0, "hoimaughe", id)
			
		}
		
	}
}
stock ham_strip_user_weapon(id, iCswId, iSlot = 0, bool:bSwitchIfActive = true)
{
	new iWeapon
	if( !iSlot )
	{
		new const iWeaponsSlots[] = {
			-1,
			2, //CSW_P228
			-1,
			1, //CSW_SCOUT
			4, //CSW_HEGRENADE
			1, //CSW_XM1014
			5, //CSW_C4
			1, //CSW_MAC10
			1, //CSW_AUG
			4, //CSW_SMOKEGRENADE
			2, //CSW_ELITE
			2, //CSW_FIVESEVEN
			1, //CSW_UMP45
			1, //CSW_SG550
			1, //CSW_GALIL
			1, //CSW_FAMAS
			2, //CSW_USP
			2, //CSW_GLOCK18
			1, //CSW_AWP
			1, //CSW_MP5NAVY
			1, //CSW_M249
			1, //CSW_M3
			1, //CSW_M4A1
			1, //CSW_TMP
			1, //CSW_G3SG1
			4, //CSW_FLASHBANG
			2, //CSW_DEAGLE
			1, //CSW_SG552
			1, //CSW_AK47
			3, //CSW_KNIFE
			1 //CSW_P90
		}
		iSlot = iWeaponsSlots[iCswId]
	}
	
	const XTRA_OFS_PLAYER = 5
	const m_rgpPlayerItems_Slot0 = 367
	
	iWeapon = get_pdata_cbase(id, m_rgpPlayerItems_Slot0 + iSlot, XTRA_OFS_PLAYER)
	
	const XTRA_OFS_WEAPON = 4
	
	while(iWeapon > 0)
	{
		if(pev_valid(iWeapon) && get_pdata_int(iWeapon, m_iId, XTRA_OFS_WEAPON) == iCswId)
		{
			break
		}
		iWeapon = get_pdata_cbase(iWeapon, m_pNext, XTRA_OFS_WEAPON)
	}
	
	if( iWeapon > 0 )
	{
		if( bSwitchIfActive && get_pdata_cbase(id, m_pActiveItem, XTRA_OFS_PLAYER) == iWeapon )
		{
			ExecuteHamB(Ham_Weapon_RetireWeapon, iWeapon)
		}
		
		if( ExecuteHamB(Ham_RemovePlayerItem, id, iWeapon) )
		{
			user_has_weapon(id, iCswId, 0)
			ExecuteHamB(Ham_Item_Kill, iWeapon)
			return 1
		}
	}
	
	return 0
} 
public message_screenfade(msg_id, msg_dest, msg_entity)
{
	if (get_msg_arg_int(4) != 255 || get_msg_arg_int(5) != 255 || get_msg_arg_int(6) != 255 || get_msg_arg_int(7) < 200)
		return PLUGIN_CONTINUE;
	
	new id = msg_entity
	if (id == g_PlayerFlasher)
		return PLUGIN_HANDLED;
	else if (Get_BitVar(g_antiflash,id)) 
		return PLUGIN_HANDLED;
	else if (get_user_team(id) == get_user_team(g_PlayerFlasher))
		return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}
public fw_SetModel(entity, szModel[]) 
{
	if(!equal(szModel, "models/w_flashbang.mdl")) 
		return FMRES_IGNORED;
	
	set_pev(entity, PEV_NADE_TYPE, NADE_TYPE_FLASH)
	
	return FMRES_IGNORED;
} 

public fw_ThinkGrenade(entity)
{
	if (!pev_valid(entity)) return HAM_IGNORED;
	
	static Float:dmgtime
	pev(entity, pev_dmgtime, dmgtime)
	
	if (dmgtime > get_gametime())
		return HAM_IGNORED;
	
	switch (pev(entity, PEV_NADE_TYPE))
	{
		case NADE_TYPE_FLASH: // Flash Grenade
		{
			g_PlayerFlasher = pev(entity, pev_owner)
			return HAM_IGNORED;
		}
	}
	
	return HAM_IGNORED;
}
/*public explosion_effect(id) {
new Origin[3]
get_user_origin(id, Origin)

message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
write_byte(TE_EXPLOSION)
write_coord(Origin[0])
write_coord(Origin[1])
write_coord(Origin[2])
write_short(exp_spr_id)
write_byte(30)
write_byte(30)
write_byte(0)  
message_end()
}*/
