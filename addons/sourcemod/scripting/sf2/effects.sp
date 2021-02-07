#if defined _sf2_effects_included
 #endinput
#endif
#define _sf2_effects_included

enum EffectEvent
{
	EffectEvent_Invalid = -1,
	EffectEvent_Constant = 0,
	EffectEvent_HitPlayer,
	EffectEvent_PlayerSeesBoss
};

enum EffectType
{
	EffectType_Invalid = -1,
	EffectType_Steam = 0,
	EffectType_DynamicLight
};

void SlenderSpawnEffects(int iBossIndex, EffectEvent iEvent)
{
	if (iBossIndex < 0 || iBossIndex >= MAX_BOSSES) return;
	
	int  iBossID = NPCGetUniqueID(iBossIndex);
	if (iBossID == -1) return;
	
	int iDifficulty = GetConVarInt(g_cvDifficulty);
	
	char sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
	NPCGetProfile(iBossIndex, sProfile, sizeof(sProfile));
	
	KvRewind(g_hConfig);
	if (!KvJumpToKey(g_hConfig, sProfile) || !KvJumpToKey(g_hConfig, "effects") || !KvGotoFirstSubKey(g_hConfig)) return;
	
	Handle hArray = CreateArray(64);
	char sSectionName[64];
	
	do
	{
		KvGetSectionName(g_hConfig, sSectionName, sizeof(sSectionName));
		PushArrayString(hArray, sSectionName);
	}
	while (KvGotoNextKey(g_hConfig));
	
	if (GetArraySize(hArray) == 0)
	{
		delete hArray;
		return;
	}
	
	char sEvent[64];
	GetEffectEventString(iEvent, sEvent, sizeof(sEvent));
	if (!sEvent[0]) 
	{
		LogError("Could not spawn effects for boss %d: invalid event string!", iBossIndex);
		delete hArray;
		return;
	}
	
	int  iSlender = NPCGetEntIndex(iBossIndex);
	float flBasePos[3], flBaseAng[3];
	
	KvRewind(g_hConfig);
	KvJumpToKey(g_hConfig, sProfile);
	KvJumpToKey(g_hConfig, "effects");
	
	for (int  i = 0, iSize = GetArraySize(hArray); i < iSize; i++)
	{
		GetArrayString(hArray, i, sSectionName, sizeof(sSectionName));
		KvJumpToKey(g_hConfig, sSectionName);
		
		// Validate effect event. Check to see if it matches with ours.
		char sEffectEvent[64];
		KvGetString(g_hConfig, "event", sEffectEvent, sizeof(sEffectEvent));
		if (strcmp(sEffectEvent, sEvent, false) == 0) 
		{
			// Validate effect type.
			char sEffectType[64];
			KvGetString(g_hConfig, "type", sEffectType, sizeof(sEffectType));
			EffectType iEffectType = GetEffectTypeFromString(sEffectType);
			
			if (iEffectType != EffectType_Invalid)
			{
				// Check base position behavior.
				char sBasePosCustom[64];
				KvGetString(g_hConfig, "origin_custom", sBasePosCustom, sizeof(sBasePosCustom));
				if (strcmp(sBasePosCustom, "&CURRENTTARGET&", false) == 0)
				{
					int  iTarget = EntRefToEntIndex(g_iSlenderTarget[iBossIndex]);
					if (!iTarget || iTarget == INVALID_ENT_REFERENCE)
					{
						LogError("Could not spawn effect %s for boss %d: unable to read position of target due to no target!");
						KvGoBack(g_hConfig);
						continue;
					}
					
					GetEntPropVector(iTarget, Prop_Data, "m_vecAbsOrigin", flBasePos);
				}
				else
				{
					if (!iSlender || iSlender == INVALID_ENT_REFERENCE)
					{
						LogError("Could not spawn effect %s for boss %d: unable to read position due to boss entity not in game!");
						KvGoBack(g_hConfig);
						continue;
					}
					
					GetEntPropVector(iSlender, Prop_Data, "m_vecAbsOrigin", flBasePos);
				}
				
				char sBaseAngCustom[64];
				KvGetString(g_hConfig, "angles_custom", sBaseAngCustom, sizeof(sBaseAngCustom));
				if (strcmp(sBaseAngCustom, "&CURRENTTARGET&", false) == 0)
				{
					int  iTarget = EntRefToEntIndex(g_iSlenderTarget[iBossIndex]);
					if (!iTarget || iTarget == INVALID_ENT_REFERENCE)
					{
						LogError("Could not spawn effect %s for boss %d: unable to read angles of target due to no target!");
						KvGoBack(g_hConfig);
						continue;
					}
					
					GetEntPropVector(iTarget, Prop_Data, "m_angAbsRotation", flBaseAng);
				}
				else
				{
					if (!iSlender || iSlender == INVALID_ENT_REFERENCE)
					{
						LogError("Could not spawn effect %s for boss %d: unable to read angles due to boss entity not in game!");
						KvGoBack(g_hConfig);
						continue;
					}
					
					GetEntPropVector(iSlender, Prop_Data, "m_angAbsRotation", flBaseAng);
				}
				
				int  iEnt = -1;
				
				switch (iEffectType)
				{
					case EffectType_Steam: iEnt = CreateEntityByName("env_steam");
					case EffectType_DynamicLight: iEnt = CreateEntityByName("light_dynamic");
				}
				
				if (iEnt != -1)
				{
					char sValue[PLATFORM_MAX_PATH];
					KvGetString(g_hConfig, "renderamt", sValue, sizeof(sValue), "255");
					DispatchKeyValue(iEnt, "renderamt", sValue);
					KvGetString(g_hConfig, "rendermode", sValue, sizeof(sValue));
					DispatchKeyValue(iEnt, "rendermode", sValue);
					KvGetString(g_hConfig, "renderfx", sValue, sizeof(sValue), "0");
					DispatchKeyValue(iEnt, "renderfx", sValue);
					KvGetString(g_hConfig, "spawnflags", sValue, sizeof(sValue));
					DispatchKeyValue(iEnt, "spawnflags", sValue);

					float flEffectPos[3], flEffectAng[3];
					
					KvGetVector(g_hConfig, "origin", flEffectPos);
					KvGetVector(g_hConfig, "angles", flEffectAng);
					VectorTransform(flEffectPos, flBasePos, flBaseAng, flEffectPos);
					AddVectors(flEffectAng, flBaseAng, flEffectAng);
					TeleportEntity(iEnt, flEffectPos, flEffectAng, NULL_VECTOR);
					
					switch (iEffectType)
					{
						case EffectType_Steam:
						{
							KvGetString(g_hConfig, "spreadspeed", sValue, sizeof(sValue));
							DispatchKeyValue(iEnt, "SpreadSpeed", sValue);
							KvGetString(g_hConfig, "speed", sValue, sizeof(sValue));
							DispatchKeyValue(iEnt, "Speed", sValue);
							KvGetString(g_hConfig, "startsize", sValue, sizeof(sValue));
							DispatchKeyValue(iEnt, "StartSize", sValue);
							KvGetString(g_hConfig, "endsize", sValue, sizeof(sValue));
							DispatchKeyValue(iEnt, "EndSize", sValue);
							KvGetString(g_hConfig, "rate", sValue, sizeof(sValue));
							DispatchKeyValue(iEnt, "Rate", sValue);
							KvGetString(g_hConfig, "jetlength", sValue, sizeof(sValue));
							DispatchKeyValue(iEnt, "Jetlength", sValue);
							KvGetString(g_hConfig, "rollspeed", sValue, sizeof(sValue));
							DispatchKeyValue(iEnt, "RollSpeed", sValue);
							KvGetString(g_hConfig, "particletype", sValue, sizeof(sValue));
							DispatchKeyValue(iEnt, "type", sValue);
							DispatchSpawn(iEnt);
							ActivateEntity(iEnt);
						}
						case EffectType_DynamicLight:
						{
							SetVariantInt(KvGetNum(g_hConfig, "brightness"));
							AcceptEntityInput(iEnt, "Brightness");
							SetVariantFloat(KvGetFloat(g_hConfig, "distance"));
							AcceptEntityInput(iEnt, "Distance");
							SetVariantFloat(KvGetFloat(g_hConfig, "distance"));
							AcceptEntityInput(iEnt, "spotlight_radius");
							SetVariantInt(KvGetNum(g_hConfig, "cone"));
							AcceptEntityInput(iEnt, "cone");
							DispatchSpawn(iEnt);
							ActivateEntity(iEnt);
							
							int  r, g, b, a;
							if (view_as<bool>(KvGetNum(g_hConfig, "difficulty_lights", 0)))
							{
								switch (iDifficulty)
								{
									case Difficulty_Normal: KvGetColor(g_hConfig, "rendercolor", r, g, b, a);
									case Difficulty_Hard: KvGetColor(g_hConfig, "rendercolor_hard", r, g, b, a);
									case Difficulty_Insane: KvGetColor(g_hConfig, "rendercolor_insane", r, g, b, a);
									case Difficulty_Nightmare: KvGetColor(g_hConfig, "rendercolor_nightmare", r, g, b, a);
									case Difficulty_Apollyon: KvGetColor(g_hConfig, "rendercolor_apollyon", r, g, b, a);
								}
							}
							else KvGetColor(g_hConfig, "rendercolor", r, g, b, a);
							SetEntityRenderColor(iEnt, r, g, b, a);
						}
					}
					
					float flLifeTime = KvGetFloat(g_hConfig, "lifetime");
					if (flLifeTime > 0.0) CreateTimer(flLifeTime, Timer_KillEntity, EntIndexToEntRef(iEnt), TIMER_FLAG_NO_MAPCHANGE);
					
					char sParentCustom[64];
					KvGetString(g_hConfig, "parent_custom", sParentCustom, sizeof(sParentCustom));
					if (strcmp(sParentCustom, "&CURRENTTARGET&", false) == 0)
					{
						int  iTarget = EntRefToEntIndex(g_iSlenderTarget[iBossIndex]);
						if (!iTarget || iTarget == INVALID_ENT_REFERENCE)
						{
							LogError("Could not parent effect %s of boss %d to current target: target does not exist!", sSectionName, iBossIndex);
							KvGoBack(g_hConfig);
							continue;
						}
					
						SetVariantString("!activator");
						AcceptEntityInput(iEnt, "SetParent", iTarget);
						if (iEffectType == EffectType_DynamicLight && view_as<bool>(KvGetNum(g_hConfig, "attach_point", 0)))
						{
							char sAttachment[PLATFORM_MAX_PATH];
							KvGetString(g_hConfig, "attachment_point", sAttachment, sizeof(sAttachment));
							if (sAttachment[0])
							{
								SetVariantString(sAttachment);
								AcceptEntityInput(iEnt, "SetParentAttachment");
							}
						}
					}
					else
					{
						if (!iSlender || iSlender == INVALID_ENT_REFERENCE)
						{
							LogError("Could not parent effect %s of boss %d to itself: boss entity does not exist!", sSectionName, iBossIndex);
							KvGoBack(g_hConfig);
							continue;
						}
						
						SetVariantString("!activator");
						AcceptEntityInput(iEnt, "SetParent", iSlender);
						if (iEffectType == EffectType_DynamicLight && view_as<bool>(KvGetNum(g_hConfig, "attach_point", 0)))
						{
							char sAttachment[PLATFORM_MAX_PATH];
							KvGetString(g_hConfig, "attachment_point", sAttachment, sizeof(sAttachment));
							if (sAttachment[0])
							{
								SetVariantString(sAttachment);
								AcceptEntityInput(iEnt, "SetParentAttachment");
							}
						}
					}
					
					switch (iEffectType)
					{
						case EffectType_Steam,
							EffectType_DynamicLight: 
						{
							AcceptEntityInput(iEnt, "TurnOn");
						}
					}
				}
			}
			else
			{
				LogError("Could not spawn effect %s for boss %d: invalid type!", sSectionName, iBossIndex);
			}
		}
		
		KvGoBack(g_hConfig);
	}
	
	delete hArray;
}
void SlenderRemoveEffects(int iSlender,bool bKill=false)
{
	int iEffect = -1;
	while((iEffect = FindEntityByClassname(iEffect, "light_dynamic")) > MaxClients)
	{
		if(GetEntProp(iEffect,Prop_Send,"moveparent") == iSlender)
		{
			AcceptEntityInput(iEffect, "TurnOff");
			if(bKill)
				RemoveEntity(iEffect);
		}
	}
	
	iEffect = -1;
	while((iEffect = FindEntityByClassname(iEffect, "env_steam")) > MaxClients)
	{
		if(GetEntProp(iEffect,Prop_Send,"moveparent") == iSlender)
		{
			AcceptEntityInput(iEffect, "TurnOff");
			if(bKill)
				RemoveEntity(iEffect);
		}
	}
	
	iEffect = -1;
	while((iEffect = FindEntityByClassname(iEffect, "tf_taunt_prop")) > MaxClients)
	{
		if(GetEntProp(iEffect,Prop_Send,"moveparent") == iSlender)
		{
			if(bKill)
			{
				RemoveEntity(iEffect);
				int iEnt = GetEntPropEnt(iEffect, Prop_Send, "m_hOwnerEntity");
				if (iEnt > MaxClients)
					RemoveEntity(iEnt);
			}
		}
	}
}
stock void GetEffectEventString(EffectEvent iEvent, char[] sBuffer,int iBufferLen)
{
	switch (iEvent)
	{
		case EffectEvent_Constant: strcopy(sBuffer, iBufferLen, "constant");
		case EffectEvent_HitPlayer: strcopy(sBuffer, iBufferLen, "boss_hitplayer");
		case EffectEvent_PlayerSeesBoss: strcopy(sBuffer, iBufferLen, "boss_seenbyplayer");
		default: sBuffer[0] = '\0';
	}
}

stock EffectType GetEffectTypeFromString(const char[] sType)
{
	if (strcmp(sType, "steam", false) == 0) return EffectType_Steam;
	if (strcmp(sType, "dynamiclight", false) == 0) return EffectType_DynamicLight;
	return EffectType_Invalid;
}
