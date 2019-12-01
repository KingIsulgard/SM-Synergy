#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#undef REQUIRE_PLUGIN
#undef REQUIRE_EXTENSIONS
#tryinclude <SteamWorks>
#tryinclude <updater>
#define REQUIRE_PLUGIN
#define REQUIRE_EXTENSIONS
#pragma semicolon 1;
#pragma newdecls required;
#pragma dynamic 2097152;

Handle cvaroriginals = INVALID_HANDLE;
Handle cvarmods = INVALID_HANDLE;
Handle g_DeleteClasses = INVALID_HANDLE;
Handle g_DeleteClassOrigin = INVALID_HANDLE;
Handle g_DeleteTargets = INVALID_HANDLE;
Handle g_EditClasses = INVALID_HANDLE;
Handle g_EditClassOrigin = INVALID_HANDLE;
Handle g_EditTargets = INVALID_HANDLE;
Handle g_EditClassesData = INVALID_HANDLE;
Handle g_EditClassOrgData = INVALID_HANDLE;
Handle g_EditTargetsData = INVALID_HANDLE;
Handle g_CreateEnts = INVALID_HANDLE;

int dbglvl = 0;

#define PLUGIN_VERSION "0.26"
#define UPDATE_URL "https://raw.githubusercontent.com/Balimbanana/SM-Synergy/master/edtrebuildupdater.txt"

public Plugin myinfo =
{
	name = "EDTRebuild",
	author = "Balimbanana",
	description = "Rebuilds EDT system to prevent memory leak in 56.16.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Balimbanana/SM-Synergy"
}

public void OnPluginStart()
{
	cvaroriginals = CreateArray(64);
	cvarmods = CreateArray(64);
	Handle cvar = FindConVar("edtdbg");
	if (cvar == INVALID_HANDLE) cvar = CreateConVar("edtdbg", "0", "Set debug level of EDT read.", _, true, 0.0, true, 4.0);
	dbglvl = GetConVarInt(cvar);
	HookConVarChange(cvar,dbgch);
	CloseHandle(cvar);
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name,"updater",false))
    {
        Updater_AddPlugin(PLUGIN_VERSION);
    }
}

public Action OnLevelInit(const char[] szMapName, char szMapEntities[2097152])
{
	g_DeleteClasses = CreateArray(128);
	g_DeleteClassOrigin = CreateArray(128);
	g_DeleteTargets = CreateArray(128);
	g_EditClasses = CreateArray(128);
	g_EditClassOrigin = CreateArray(128);
	g_EditTargets = CreateArray(128);
	g_EditClassesData = CreateArray(128);
	g_EditClassOrgData = CreateArray(128);
	g_EditTargetsData = CreateArray(128);
	g_CreateEnts = CreateArray(128);
	if (GetArraySize(cvaroriginals) > 0)
	{
		for (int i = 0;i<GetArraySize(cvaroriginals);i++)
		{
			char tmparr[128];
			GetArrayString(cvaroriginals,i,tmparr,sizeof(tmparr));
			ServerCommand(tmparr);
		}
		CloseHandle(cvaroriginals);
		cvaroriginals = CreateArray(64);
	}
	char curmap[128];
	Format(curmap,sizeof(curmap),"maps/%s.edt",szMapName);
	char curmap2[128];
	Format(curmap2,sizeof(curmap2),"maps/%s.edt2",szMapName);
	if ((FileExists(curmap,true,NULL_STRING)) || (FileExists(curmap2,true,NULL_STRING)))
	{
		if (FileExists(curmap2,true,NULL_STRING)) Format(curmap,sizeof(curmap),"%s",curmap2);
		if (dbglvl) PrintToServer("EDT %s exists",curmap);
		ReadEDT(curmap);
		char curbuf[4096][512];
		char rmchar[2];
		Format(rmchar,sizeof(rmchar),"%s%s",szMapEntities[0],szMapEntities[1]);
		ExplodeString(szMapEntities,"{",curbuf,4096,512);
		char tmpline[6148];
		char tmpbuf[4096];
		char buffadded[6148];
		char cls[64];
		char clsorg[64];
		char clsorground[64];
		char originch[64];
		char globalremove[64];
		char targn[64];
		char tmpexpl[4][64];
		char edtdata[128];
		char replacedata[128];
		char edt_map[64];
		char edt_landmark[64];
		char edtkey[128];
		char edtval[128];
		bool CheckDelClasses,CheckEdClasses,CheckDelClassorg,CheckDelTargets,CheckEdClassOrg,CheckEdTargets;
		if (GetArraySize(g_DeleteTargets) > 0) CheckDelTargets = true;
		if (GetArraySize(g_EditClassOrigin) > 0) CheckEdClassOrg = true;
		if (GetArraySize(g_EditTargets) > 0) CheckEdTargets = true;
		if (GetArraySize(g_DeleteClasses) > 0) CheckDelClasses = true;
		if (GetArraySize(g_EditClasses) > 0) CheckEdClasses = true;
		if (GetArraySize(g_DeleteClassOrigin) > 0) CheckDelClassorg = true;
		//Need to run create first for edt_getbspmodelfor_* keys
		if (GetArraySize(g_CreateEnts) > 0)
		{
			for (int k = 0;k<GetArraySize(g_CreateEnts);k++)
			{
				Handle passedarr = GetArrayCell(g_CreateEnts,k);
				if (passedarr != INVALID_HANDLE)
				{
					char edtclass[64];
					char edtclassorg[64];
					Format(tmpbuf,sizeof(tmpbuf),"\n{");
					for (int j = 0;j<GetArraySize(passedarr);j++)
					{
						char first[128];
						GetArrayString(passedarr,j,first,sizeof(first));
						char second[128];
						Format(second,sizeof(second),"%s",first);
						int secondpos = StrContains(first," ",false);
						if (secondpos != -1)
						{
							Format(second,sizeof(second),"%s",second[secondpos]);
							ReplaceStringEx(first,sizeof(first),second,"");
							ReplaceString(first,sizeof(first),"\"","");
							ReplaceString(second,sizeof(second),"\"","");
							TrimString(first);
							TrimString(second);
							if (StrEqual(first,"edt_getbspmodelfor_targetname",false))
							{
								char findtn[128];
								Format(findtn,sizeof(findtn),"\"targetname\" \"%s\"",second);
								for (int i = 1;i<4096;i++)
								{
									if (strlen(curbuf[i]) > 0)
									{
										if (StrContains(curbuf[i],findtn,false) != -1)
										{
											int findmdl = StrContains(curbuf[i],"\"model\"",false);
											if (findmdl != -1)
											{
												Format(tmpline,sizeof(tmpline),"%s",curbuf[i]);
												Format(tmpline,sizeof(tmpline),"%s",tmpline[findmdl]);
												ExplodeString(tmpline,"\"",tmpexpl,4,64);
												Format(first,sizeof(first),"model");
												Format(second,sizeof(second),"%s",tmpexpl[3]);
											}
											else
											{
												PrintToServer("Failed to get BSP Model from Targetname %s",second);
											}
											break;
										}
									}
								}
							}
							if (StrEqual(first,"edt_getbspmodelfor_classname",false))
							{
								Format(edtclass,sizeof(edtclass),"%s",second);
							}
							else if (StrEqual(first,"edt_getbspmodelfor_origin",false))
							{
								Format(edtclassorg,sizeof(edtclassorg),"%s",second);
							}
							else Format(tmpbuf,sizeof(tmpbuf),"%s\n\"%s\" \"%s\"",tmpbuf,first,second);
						}
					}
					if ((strlen(edtclass) > 0) && (strlen(edtclassorg) > 0))
					{
						char findclass[128];
						Format(findclass,sizeof(findclass),"\"classname\" \"%s\"",edtclass);
						char findorg[128];
						Format(findorg,sizeof(findorg),"\"origin\" \"%s\"",edtclassorg);
						for (int i = 1;i<4096;i++)
						{
							if (strlen(curbuf[i]) > 0)
							{
								if ((StrContains(curbuf[i],findclass,false) != -1) && (StrContains(curbuf[i],findorg,false) != -1))
								{
									int findmdl = StrContains(curbuf[i],"\"model\"",false);
									if (findmdl != -1)
									{
										Format(tmpline,sizeof(tmpline),"%s",curbuf[i]);
										Format(tmpline,sizeof(tmpline),"%s",tmpline[findmdl]);
										ExplodeString(tmpline,"\"",tmpexpl,4,64);
										Format(tmpbuf,sizeof(tmpbuf),"%s\n\"model\" \"%s\"",tmpbuf,tmpexpl[3]);
									}
									else
									{
										PrintToServer("Failed to get BSP Model from Classname %s at origin %s",edtclass,edtclassorg);
									}
									break;
								}
							}
						}
					}
					Format(tmpbuf,sizeof(tmpbuf),"%s\n}",tmpbuf);
					if (dbglvl == 4) PrintToServer("Create %s",tmpbuf);
					StrCat(szMapEntities,sizeof(szMapEntities),tmpbuf);
					CloseHandle(passedarr);
				}
			}
		}
		for (int i = 1;i<4096;i++)
		{
			if (strlen(curbuf[i]) > 0)
			{
				Format(tmpline,sizeof(tmpline),"%s",curbuf[i]);
				int findbufend = StrContains(szMapEntities,tmpline,false);
				if (StrContains(tmpline,"}",false) == -1)
				{
					Format(tmpbuf,sizeof(tmpbuf),"%s",szMapEntities[findbufend+strlen(tmpline)]);
					int findend = StrContains(tmpbuf,"}",false);
					if (findend != -1)
					{
						Format(tmpbuf,findend+2,"%s",tmpbuf);
						Format(tmpline,sizeof(tmpline),"%s%s",tmpline,tmpbuf);
					}
				}
				bool RunEDT = false;
				if (CheckDelClasses)
				{
					for (int j = 0;j<GetArraySize(g_DeleteClasses);j++)
					{
						GetArrayString(g_DeleteClasses,j,cls,sizeof(cls));
						if (StrContains(tmpline,cls,false) != -1)
						{
							RunEDT = true;
							break;
						}
					}
				}
				if ((!RunEDT) && (CheckEdClasses))
				{
					for (int j = 0;j<GetArraySize(g_EditClasses);j++)
					{
						GetArrayString(g_EditClasses,j,cls,sizeof(cls));
						if (StrContains(tmpline,cls,false) != -1)
						{
							RunEDT = true;
							break;
						}
					}
				}
				if ((!RunEDT) && (CheckDelTargets))
				{
					for (int j = 0;j<GetArraySize(g_DeleteTargets);j++)
					{
						GetArrayString(g_DeleteTargets,j,cls,sizeof(cls));
						if (StrContains(tmpline,cls,false) != -1)
						{
							RunEDT = true;
							break;
						}
					}
				}
				if ((!RunEDT) && (CheckEdTargets))
				{
					for (int j = 0;j<GetArraySize(g_EditTargets);j++)
					{
						GetArrayString(g_EditTargets,j,cls,sizeof(cls));
						if (StrContains(tmpline,cls,false) != -1)
						{
							RunEDT = true;
							break;
						}
					}
				}
				if ((!RunEDT) && (CheckDelClassorg))
				{
					for (int j = 0;j<GetArraySize(g_DeleteClassOrigin);j++)
					{
						GetArrayString(g_DeleteClassOrigin,j,cls,sizeof(cls));
						int findend = StrContains(cls,",",false);
						if (findend != -1)
						{
							Format(clsorg,findend+1,"%s",cls);
							ReplaceString(cls,sizeof(cls),clsorg,"");
							ReplaceString(cls,sizeof(cls),",","");
							if (StrContains(tmpline,cls,false) != -1)
							{
								RunEDT = true;
								break;
							}
						}
					}
				}
				if ((!RunEDT) && (CheckEdClassOrg))
				{
					for (int j = 0;j<GetArraySize(g_EditClassOrigin);j++)
					{
						GetArrayString(g_EditClassOrigin,j,cls,sizeof(cls));
						int findend = StrContains(cls,",",false);
						if (findend != -1)
						{
							Format(clsorg,findend+1,"%s",cls);
							ReplaceString(cls,sizeof(cls),clsorg,"");
							ReplaceString(cls,sizeof(cls),",","");
							if (StrContains(tmpline,cls,false) != -1)
							{
								RunEDT = true;
								break;
							}
						}
					}
				}
				if (RunEDT)
				{
					originch = "";
					cls = "";
					clsorground = "";
					targn = "";
					//if (StrContains(curbuf[i],"",false) != -1) ReplaceString(curbuf[i],sizeof(curbuf[]),"",",");
					int findglobals = StrContains(tmpline,"\"globalname\"",false);
					if (findglobals != -1)
					{
						Format(globalremove,sizeof(globalremove),"%s",tmpline[findglobals]);
						ExplodeString(globalremove,"\"",tmpexpl,4,64);
						Format(globalremove,sizeof(globalremove),"%s",tmpexpl[3]);
						TrimString(globalremove);
						Format(globalremove,sizeof(globalremove),"\"globalname\" \"%s\"\n",globalremove);
						ReplaceString(szMapEntities,sizeof(szMapEntities),globalremove,"");
						ReplaceString(tmpline,sizeof(tmpline),globalremove,"");
					}
					int findcls = StrContains(tmpline,"\"classname\" \"",false);
					if (findcls != -1)
					{
						Format(cls,sizeof(cls),"%s",tmpline[findcls]);
						ReplaceStringEx(cls,sizeof(cls),"\"classname\" \"","");
						int findend = StrContains(cls,"\"",false);
						if (findend != -1)
						{
							Format(cls,findend+1,"%s",cls);
							ReplaceString(cls,sizeof(cls),"\"","");
							TrimString(cls);
						}
						else
						{
							Format(cls,sizeof(cls),"%s",tmpline[findcls]);
							ExplodeString(cls,"\"",tmpexpl,4,64);
							Format(cls,sizeof(cls),"%s",tmpexpl[3]);
							TrimString(cls);
						}
					}
					int findorg = StrContains(tmpline,"\"origin\" \"",false);
					if (findorg != -1)
					{
						Format(originch,sizeof(originch),"%s",tmpline[findorg]);
						ReplaceStringEx(originch,sizeof(originch),"\"origin\" \"","");
						int findend = StrContains(originch,"\"",false);
						if (findend != -1)
						{
							Format(originch,findend+1,"%s",originch);
							ReplaceString(originch,sizeof(originch),"\"","");
							TrimString(originch);
						}
						else
						{
							Format(originch,sizeof(originch),"%s",tmpline[findorg]);
							ExplodeString(originch,"\"",tmpexpl,4,64);
							Format(originch,sizeof(originch),"%s",tmpexpl[3]);
							TrimString(originch);
						}
					}
					int findtargn = StrContains(tmpline,"\"targetname\" \"",false);
					if (findtargn != -1)
					{
						Format(targn,sizeof(targn),"%s",tmpline[findtargn]);
						ReplaceStringEx(targn,sizeof(targn),"\"targetname\" \"","");
						int findend = StrContains(targn,"\"",false);
						if (findend != -1)
						{
							Format(targn,findend+1,"%s",targn);
							ReplaceString(targn,sizeof(targn),"\"","");
							TrimString(targn);
						}
						else
						{
							Format(targn,sizeof(targn),"%s",tmpline[findtargn]);
							ExplodeString(targn,"\"",tmpexpl,4,64);
							Format(targn,sizeof(targn),"%s",tmpexpl[3]);
							TrimString(targn);
						}
					}
					Format(clsorg,sizeof(clsorg),"%s,%s",cls,originch);
					if (StrEqual(cls,"logic_auto",false))
					{
						float org[3];
						ExplodeString(originch," ",tmpexpl,4,64);
						org[0] = StringToFloat(tmpexpl[0]);
						org[1] = StringToFloat(tmpexpl[1]);
						org[2] = StringToFloat(tmpexpl[2]);
						Format(clsorground,sizeof(clsorground),"%s,%i %i %i",cls,RoundFloat(org[0]),RoundFloat(org[1]),RoundFloat(org[2]));
					}
					if ((FindStringInArray(g_DeleteClasses,cls) != -1) || (FindStringInArray(g_DeleteClassOrigin,clsorg) != -1) || ((FindStringInArray(g_DeleteClassOrigin,clsorground) != -1) && (strlen(clsorground) > 0)) || ((FindStringInArray(g_DeleteTargets,targn) != -1) && (strlen(targn) > 0)))
					{
						int findprev = StrContains(szMapEntities,tmpline,false);
						if (findprev != -1)
						{
							Format(tmpline,sizeof(tmpline),"%s%s",rmchar,tmpline);
							ReplaceString(szMapEntities,sizeof(szMapEntities),tmpline,"");
							if (dbglvl == 4) PrintToServer("Delete %s\n%s from %s %i %i",cls,tmpline,clsorg,FindStringInArray(g_DeleteClassOrigin,clsorg),FindStringInArray(g_DeleteClasses,cls));
							/*
							if (StrContains(tmpline,"}",false) == -1)
							{
								Format(tmpbuf,sizeof(tmpbuf),"%s",szMapEntities[findprev-1]);
								int findend = StrContains(tmpbuf,"}",false);
								if (findend != -1)
								{
									Format(tmpbuf,findend+2,"%s",tmpbuf);
								}
								//PrintToServer("RM %s %i",tmpbuf,findend);
								ReplaceString(szMapEntities,sizeof(szMapEntities),tmpbuf,"");
							}
							*/
						}
					}
					else if ((FindStringInArray(g_EditClasses,cls) != -1) || (FindStringInArray(g_EditClassOrigin,clsorg) != -1) || (FindStringInArray(g_EditTargets,targn) != -1))
					{
						Handle passedarr = INVALID_HANDLE;
						int findarr = FindStringInArray(g_EditTargets,targn);
						if (findarr != -1) passedarr = GetArrayCell(g_EditTargetsData,findarr);
						if (findarr == -1) findarr = FindStringInArray(g_EditClassOrigin,clsorg);
						if ((findarr != -1) && (passedarr == INVALID_HANDLE)) passedarr = GetArrayCell(g_EditClassOrgData,findarr);
						if (findarr == -1) findarr = FindStringInArray(g_EditClasses,cls);
						if ((findarr != -1) && (passedarr == INVALID_HANDLE)) passedarr = GetArrayCell(g_EditClassesData,findarr);
						if (findarr != -1)
						{
							if (passedarr != INVALID_HANDLE)
							{
								for (int j = 0;j<GetArraySize(passedarr);j++)
								{
									GetArrayString(passedarr,j,edtdata,sizeof(edtdata));
									//ExplodeString(edtdata," ",tmpexpl,4,64);
									int findend = StrContains(edtdata," ",false);
									if (findend != -1)
									{
										Format(edtkey,findend+1,"%s",edtdata);
									}
									//Format(edtkey,sizeof(edtkey),"%s",tmpexpl[0]);
									Format(edtval,sizeof(edtval),"%s",edtdata);
									ReplaceStringEx(edtval,sizeof(edtval),edtkey,"");
									TrimString(edtval);
									if (StrContains(edtkey,"\"",false) != -1) ReplaceString(edtkey,sizeof(edtkey),"\"","");
									Format(edtkey,sizeof(edtkey),"\"%s\"",edtkey);
									if (StrContains(edtval,"\"",false) != -1) ReplaceString(edtval,sizeof(edtval),"\"","");
									int findedit = StrContains(tmpline,edtkey,false);
									if (StrEqual(edtkey,"\"edt_map\"",false))
									{
										findedit = StrContains(tmpline,"\"map\" \"",false);
										if (findedit != -1)
										{
											Format(tmpbuf,sizeof(tmpbuf),"%s",tmpline[findedit]);
											ReplaceStringEx(tmpbuf,sizeof(tmpbuf),"\"map\" ","");
											findend = StrContains(tmpbuf,"\n",false);
											if (findend != -1)
											{
												Format(tmpbuf,findend,"%s",tmpbuf);
												ReplaceString(tmpbuf,sizeof(tmpbuf),"\"","");
												TrimString(tmpbuf);
												if (StrEqual(tmpbuf,edtval,false))
												{
													Format(edt_map,sizeof(edt_map),"%s",edtval);
													edtkey = "";
												}
												else break;
											}
										}
									}
									if (StrEqual(edtkey,"\"edt_landmark\"",false))
									{
										findedit = StrContains(tmpline,"\"landmark\" \"",false);
										if (findedit != -1)
										{
											Format(tmpbuf,sizeof(tmpbuf),"%s",tmpline[findedit]);
											ReplaceStringEx(tmpbuf,sizeof(tmpbuf),"\"landmark\" ","");
											findend = StrContains(tmpbuf,"\n",false);
											if (findend != -1)
											{
												Format(tmpbuf,findend,"%s",tmpbuf);
												ReplaceString(tmpbuf,sizeof(tmpbuf),"\"","");
												TrimString(tmpbuf);
												if (StrEqual(tmpbuf,edtval,false))
												{
													Format(edt_landmark,sizeof(edt_landmark),"%s",edtval);
													edtkey = "";
												}
												else break;
											}
										}
									}
									if ((StrEqual(edtkey,"\"edt_addspawnflags\"",false)) || (StrEqual(edtkey,"\"edt_addedspawnflags\"",false)) || (StrEqual(edtkey,"\"edt_removespawnflags\"",false)))
									{
										findedit = StrContains(tmpline,"\"spawnflags\"",false);
									}
									//if ((findedit != -1) && (strlen(edt_landmark) > 0) && (strlen(edt_map) > 0))
									if ((findedit != -1) && (StrContains(edtkey,"\"On",false) != 0) && (StrContains(edtkey,"\"PlayerO",false) != 0) && (StrContains(edtkey,"\"Pressed",false) != 0) && (StrContains(edtkey,"\"Unpressed",false) != 0) && (strlen(edtkey) > 1))
									{
										Format(buffadded,sizeof(buffadded),"%s",tmpline[findedit]);
										ExplodeString(buffadded,"\"",tmpexpl,4,64);
										if (strlen(tmpexpl[1]) < 3) Format(replacedata,sizeof(replacedata),"\"%s\" \"%s\"",tmpexpl[0],tmpexpl[2]);
										else Format(replacedata,sizeof(replacedata),"\"%s\" \"%s\"",tmpexpl[1],tmpexpl[3]);
										TrimString(replacedata);
										Format(buffadded,sizeof(buffadded),"%s",tmpline);
										if ((StrEqual(edtkey,"\"edt_addspawnflags\"",false)) || (StrEqual(edtkey,"\"edt_addedspawnflags\"",false)))
										{
											int curval = 0;
											if (strlen(tmpexpl[2]) > 0) curval = StringToInt(tmpexpl[2]);
											else curval = StringToInt(tmpexpl[3]);
											Format(edtval,sizeof(edtval),"%i",curval+StringToInt(edtval));
											Format(edtkey,sizeof(edtkey),"\"spawnflags\"");
										}
										else if (StrEqual(edtkey,"\"edt_removespawnflags\"",false))
										{
											int checkneg = 0;
											if (strlen(tmpexpl[2]) > 0) checkneg = StringToInt(tmpexpl[2]);
											else checkneg = StringToInt(tmpexpl[3]);
											checkneg = checkneg-StringToInt(edtval);
											if (checkneg < 0) checkneg = 0;
											Format(edtval,sizeof(edtval),"%i",checkneg);
											Format(edtkey,sizeof(edtkey),"\"spawnflags\"");
										}
										Format(edtkey,sizeof(edtkey),"%s \"%s\"",edtkey,edtval);
										if (StrEqual(edtkey,replacedata,false)) continue;
										if (dbglvl >= 3) PrintToServer("Replace %s with %s",replacedata,edtkey);
										ReplaceString(buffadded,sizeof(buffadded),replacedata,edtkey);
										if (StrContains(szMapEntities,tmpline,false) != -1)
										{
											ReplaceString(szMapEntities,sizeof(szMapEntities),tmpline,buffadded);
											//Additional replaces
											Format(tmpline,sizeof(tmpline),"%s",buffadded);
										}
									}
									else if ((strlen(tmpline) > 0) && (strlen(edtkey) > 1))
									{
										//{
										//Format(tmpline,sizeof(tmpline),"%s%s",rmchar,tmpline);
										Format(buffadded,sizeof(buffadded),"%s",tmpline);
										ReplaceString(buffadded,sizeof(buffadded),"}","");
										if (StrContains(buffadded,"\n\n",false) != -1) ReplaceString(buffadded,sizeof(buffadded),"\n\n","\n");
										if (dbglvl >= 3) PrintToServer("Add KV to %s %s\n%s %s",clsorg,targn,edtkey,edtval);
										Format(buffadded,sizeof(buffadded),"%s%s \"%s\"\n}\n",buffadded,edtkey,edtval);
										ReplaceString(szMapEntities,sizeof(szMapEntities),tmpline,buffadded);
										Format(tmpline,sizeof(tmpline),"%s",buffadded);
									}
								}
							}
						}
					}
				}
			}
			else break;
		}
		ClearArrayHandles(g_EditClassesData);
		ClearArrayHandles(g_EditTargetsData);
		ClearArrayHandles(g_EditClassOrgData);
		CloseHandle(g_DeleteClasses);
		CloseHandle(g_DeleteClassOrigin);
		CloseHandle(g_DeleteTargets);
		CloseHandle(g_EditClasses);
		CloseHandle(g_EditClassOrigin);
		CloseHandle(g_EditTargets);
		CloseHandle(g_EditClassesData);
		CloseHandle(g_EditTargetsData);
		CloseHandle(g_EditClassOrgData);
		CloseHandle(g_CreateEnts);
		char szMapNameadj[64];
		char contentdata[64];
		Handle cvar = FindConVar("content_metadata");
		if (cvar != INVALID_HANDLE)
		{
			GetConVarString(cvar,contentdata,sizeof(contentdata));
			char fixuptmp[16][16];
			ExplodeString(contentdata," ",fixuptmp,16,16,true);
			Format(contentdata,sizeof(contentdata),"%s",fixuptmp[2]);
		}
		CloseHandle(cvar);
		if (strlen(contentdata) < 1) Format(szMapNameadj,sizeof(szMapNameadj),"maps/ent_cache/%s.ent",szMapName);
		else Format(szMapNameadj,sizeof(szMapNameadj),"maps/ent_cache/%s_%s.ent",contentdata,szMapName);
		Handle writefile = OpenFile(szMapNameadj,"wb",true,NULL_STRING);
		if (writefile != INVALID_HANDLE)
		{
			WriteFileString(writefile,szMapEntities,false);
		}
		CloseHandle(writefile);
		if (dbglvl > 0) PrintToServer("Finished EntCache Rebuild");
		return Plugin_Changed;
	}
	else if (dbglvl > 0) PrintToServer("No EDT found at %s or %s",curmap,curmap2);
	CloseHandle(g_DeleteClasses);
	CloseHandle(g_DeleteClassOrigin);
	CloseHandle(g_DeleteTargets);
	CloseHandle(g_EditClasses);
	CloseHandle(g_EditClassOrigin);
	CloseHandle(g_EditTargets);
	CloseHandle(g_EditClassesData);
	CloseHandle(g_EditTargetsData);
	CloseHandle(g_EditClassOrgData);
	CloseHandle(g_CreateEnts);
	return Plugin_Continue;
}

void ClearArrayHandles(Handle array)
{
	if (array != INVALID_HANDLE)
	{
		if (view_as<int>(array) != 1634494062)
		{
			if (GetArraySize(array) > 0)
			{
				for (int i = 0;i<GetArraySize(array);i++)
				{
					Handle closearr = GetArrayCell(array,i);
					if (closearr != INVALID_HANDLE) CloseHandle(closearr);
				}
			}
		}
	}
}

public int Updater_OnPluginUpdated()
{
	Handle nullpl = INVALID_HANDLE;
	ReloadPlugin(nullpl);
}

public void OnMapStart()
{
	if (GetArraySize(cvarmods) > 0)
	{
		for (int i = 0;i<GetArraySize(cvarmods);i++)
		{
			char tmparr[64];
			GetArrayString(cvarmods,i,tmparr,sizeof(tmparr));
			ServerCommand("%s",tmparr);
		}
		CloseHandle(cvarmods);
		cvarmods = CreateArray(64);
	}
}

void ReadEDT(char[] edtfile)
{
	if (FileExists(edtfile,true,NULL_STRING))
	{
		bool CreatingEnt = false;
		bool EditingEnt = false;
		bool DeletingEnt = false;
		bool CVars = false;
		bool origindefined = false;
		bool TargnDefined = false;
		bool ReadString = false;
		bool reading = true;
		char line[512];
		char cls[128];
		char targn[64];
		char originch[128];
		int linenum = 0;
		Handle passedarr = CreateArray(64);
		Handle filehandle = INVALID_HANDLE;
		if (FileExists(edtfile,false)) filehandle = OpenFile(edtfile,"rt",false);
		else filehandle = OpenFile(edtfile,"rt",true,NULL_STRING);
		while(reading && (!IsEndOfFile(filehandle)))
		{
			if (!ReadString) reading = ReadFileLine(filehandle,line,sizeof(line));
			else
			{
				int readstatus = ReadFileString(filehandle,line,sizeof(line));
				if (readstatus == -1)
				{
					reading = false;
					break;
				}
				else reading = true;
			}
			TrimString(line);
			linenum+=1;
			if (((strlen(line) > 0) || (ReadString)) && (StrContains(line,"//",false) != 0))
			{
				if ((strlen(line) < 4) && (StrContains(line,"//",false) != 0) && (!StrEqual(line,"{",false)) && (!StrEqual(line,"}",false)) && (!StrEqual(line,"} }",false)) && (!StrEqual(line,"}}",false)))
				{
					char additional[32];
					ReadFileString(filehandle,additional,sizeof(additional));
					Format(line,sizeof(line),"%s%s",line,additional);
					while (ReadFileString(filehandle,additional,sizeof(additional)) > 0)
					{
						if (StrEqual(additional,"\n",false))
						{
							ReplaceString(line,sizeof(line),"\n","");
							ReadString = true;
							break;
						}
						Format(line,sizeof(line),"%s%s",line,additional);
					}
					TrimString(line);
				}
				if (StrContains(line,"//",false) != 0)
				{
					int commentpos = StrContains(line,"//",false);
					if (commentpos != -1)
					{
						Format(line,commentpos+1,"%s",line);
					}
				}
				if ((StrEqual(line,"console",false)) || (StrContains(line,"console",false) != -1))
				{
					CVars = true;
				}
				if (CVars)
				{
					if ((StrContains(line,"entity",false) != -1) || (StrEqual(line,"}",false)))
					{
						CVars = false;
					}
					else
					{
						Handle consolearr = CreateArray(16);
						FormatKVs(consolearr,line,"");
						/*
						Handle tmphndl = FormatKVs(consolearr,line,"");
						consolearr = CloneArray(tmphndl);
						CloseHandle(tmphndl);
						*/
						if (GetArraySize(consolearr) > 0)
						{
							for (int i = 0;i<GetArraySize(consolearr);i++)
							{
								char tmparr[128];
								GetArrayString(consolearr,i,tmparr,sizeof(tmparr));
								if (dbglvl) PrintToServer("CVar %s",tmparr);
								char kvs[4][64];
								ExplodeString(tmparr," ",kvs,4,64);
								Handle cvarchk = FindConVar(kvs[0]);
								if (cvarchk != INVALID_HANDLE)
								{
									char originalval[128];
									GetConVarString(cvarchk,originalval,sizeof(originalval));
									Format(originalval,sizeof(originalval),"%s %s",kvs[0],originalval);
									if (FindStringInArray(cvaroriginals,originalval) == -1) PushArrayString(cvaroriginals,originalval);
								}
								CloseHandle(cvarchk);
								ServerCommand("%s",tmparr);
								if (FindStringInArray(cvarmods,tmparr) == -1) PushArrayString(cvarmods,tmparr);
							}
						}
						CloseHandle(consolearr);
					}
				}
				if ((StrContains(line,"create",false) == 0) || (StrContains(line,"create",false) == 1))
					CreatingEnt = true;
				else if ((StrContains(line,"edit",false) == 0) || (StrContains(line,"edit",false) == 1))
					EditingEnt = true;
				else if ((StrContains(line,"delete",false) == 0) || (StrContains(line,"delete",false) == 1))
					DeletingEnt = true;
				if ((StrContains(line,"classname",false) != -1) && (strlen(cls) < 1))
				{
					char removeprev[64];
					int findclass = StrContains(line,"classname",false);
					if (findclass != -1)
					{
						Format(removeprev,findclass+1,"%s",line);
					}
					Format(cls,sizeof(cls),"%s",line);
					if (strlen(removeprev) > 0)
						ReplaceString(cls,sizeof(cls),removeprev,"");
					if (StrContains(cls,"\"",false) != -1)
					{
						ReplaceString(cls,sizeof(cls),"\"","");
					}
					ReplaceString(cls,sizeof(cls),"}","");
					ReplaceStringEx(cls,sizeof(cls),"classname","");
					TrimString(cls);
					char kvs[64][64];
					ExplodeString(cls," ",kvs,64,64);
					Format(cls,sizeof(cls),"%s",kvs[0]);
					TrimString(cls);
				}
				if ((StrContains(line,"origin",false) != -1) && (!origindefined))
				{
					char removeprev[64];
					int findclass = StrContains(line,"origin",false);
					int containval = StrContains(line,"values",false);
					if (findclass != -1)
					{
						bool nosetorg = false;
						if (containval != -1)
						{
							if (findclass > containval) nosetorg = true;
						}
						if (!nosetorg) Format(removeprev,findclass+1,"%s",line);
					}
					Format(originch,sizeof(originch),"%s",line);
					if (strlen(removeprev) > 0)
						ReplaceString(originch,sizeof(originch),removeprev,"");
					ReplaceString(originch,sizeof(originch),"\"","");
					ReplaceString(originch,sizeof(originch),"origin","");
					ReplaceString(originch,sizeof(originch),"{","");
					ReplaceString(originch,sizeof(originch),"}","");
					TrimString(originch);
					char kvs[64][64];
					ExplodeString(originch," ",kvs,64,64);
					Format(originch,sizeof(originch),"%s %s %s",kvs[0],kvs[1],kvs[2]);
					origindefined = true;
				}
				if ((StrContains(line,"targetname",false) != -1) && ((EditingEnt) || (DeletingEnt)) && (!TargnDefined))
				{
					bool gettn = true;
					if (StrContains(line,"values",false) != -1)
					{
						if ((StrContains(line,"targetname",false)) >= (StrContains(line,"values",false))) gettn = false;
					}
					if (gettn)
					{
						Handle tmp = CreateArray(16);
						FormatKVs(tmp,line,"targetname");
						/*
						Handle tmphndl = FormatKVs(tmp,line,"targetname");
						tmp = CloneArray(tmphndl);
						CloseHandle(tmphndl);
						*/
						if (GetArraySize(tmp) > 0)
						{
							char tmparr[256];
							GetArrayString(tmp,0,tmparr,sizeof(tmparr));
							char kvs[64][64];
							ExplodeString(tmparr," ",kvs,64,64);
							Format(targn,sizeof(targn),"%s",kvs[0]);
							ReplaceString(targn,sizeof(targn),"\"","");
							ReplaceString(targn,sizeof(targn),"}","");
							if (strlen(targn) > 0) TargnDefined = true;
						}
						CloseHandle(tmp);
					}
				}
				if (((CreatingEnt) || (EditingEnt) || (DeletingEnt)) && (strlen(line) > 0))
				{
					FormatKVs(passedarr,line,cls);
					/*
					Handle tmphndl = FormatKVs(passedarr,line,cls);
					passedarr = CloneArray(tmphndl);
					CloseHandle(tmphndl);
					*/
				}
				if ((StrContains(line,"}",false) != -1) && (CreatingEnt))
				{
					if (strlen(cls) > 0)
					{
						char edtcls[64];
						Format(edtcls,sizeof(edtcls),"%s",cls);
						if (dbglvl > 0) PrintToServer("Create %s at origin %s With %i KVs",cls,originch,GetArraySize(passedarr));
						else if (dbglvl) PrintToServer("Create %s at origin %s",cls,originch);
						Format(edtcls,sizeof(edtcls),"classname \"%s\"",edtcls);
						if (FindStringInArray(passedarr,edtcls) == -1) PushArrayString(passedarr,edtcls);
						Handle dupearr = CloneArray(passedarr);
						PushArrayCell(g_CreateEnts,dupearr);
					}
					else PrintToServer("EDT Error: Attempted to create entity with no classname on line %i",linenum);
					ClearArray(passedarr);
					cls = "";
					targn = "";
					originch = "";
					origindefined = false;
					CreatingEnt = false;
					EditingEnt = false;
					DeletingEnt = false;
					TargnDefined = false;
				}
				if ((StrContains(line,"}",false) != -1) && (EditingEnt) || (DeletingEnt))
				{
					if ((origindefined) && (strlen(cls) > 0))
					{
						if (DeletingEnt)
						{
							if (dbglvl) PrintToServer("Delete %s at origin %s",cls,originch);
							char deletion[64];
							Format(deletion,sizeof(deletion),"%s,%s",cls,originch);
							if (FindStringInArray(g_DeleteClassOrigin,deletion) == -1) PushArrayString(g_DeleteClassOrigin,deletion);
						}
						else
						{
							if (dbglvl > 0) PrintToServer("Edit %s at origin %s with %i KVs",cls,originch,GetArraySize(passedarr));
							else if (dbglvl) PrintToServer("Edit %s at origin %s",cls,originch);
							char resetent[128];
							Format(resetent,sizeof(resetent),"%s,%s",cls,originch);
							Handle dupearr = CloneArray(passedarr);
							PushArrayString(g_EditClassOrigin,resetent);
							PushArrayCell(g_EditClassOrgData,dupearr);
						}
					}
					else if ((!TargnDefined) && (strlen(cls) > 0))
					{
						if (DeletingEnt)
						{
							if (dbglvl) PrintToServer("Delete all %s",cls);
							if (FindStringInArray(g_DeleteClasses,cls) == -1) PushArrayString(g_DeleteClasses,cls);
						}
						else
						{
							if (dbglvl) PrintToServer("Edit all %s",cls);
							if (FindStringInArray(g_EditClasses,cls) == -1)
							{
								PushArrayString(g_EditClasses,cls);
								Handle dupearr = CloneArray(passedarr);
								PushArrayCell(g_EditClassesData,dupearr);
							}
						}
					}
					else if (strlen(targn) > 0)
					{
						if (DeletingEnt)
						{
							if (dbglvl) PrintToServer("Delete all by targetname %s",targn);
							if (FindStringInArray(g_DeleteTargets,targn) == -1) PushArrayString(g_DeleteTargets,targn);
						}
						else
						{
							if (dbglvl) PrintToServer("Edit all by targetname %s",targn);
							if (FindStringInArray(g_EditTargets,targn) == -1)
							{
								PushArrayString(g_EditTargets,targn);
								Handle dupearr = CloneArray(passedarr);
								PushArrayCell(g_EditTargetsData,dupearr);
							}
						}
					}
					ClearArray(passedarr);
					cls = "";
					targn = "";
					originch = "";
					origindefined = false;
					CreatingEnt = false;
					EditingEnt = false;
					DeletingEnt = false;
					TargnDefined = false;
				}
			}
			if ((view_as<int>(filehandle) == 2002874483) || (linenum > 20000))
			{
				PrintToServer("EDTRead Ended at line %i",linenum);
				CloseHandle(passedarr);
				return;
			}
		}
		if (dbglvl > 1) PrintToServer("EDTRead Ended at line %i",linenum+1);
		CloseHandle(passedarr);
		CloseHandle(filehandle);
	}
	return;
}
//public Handle FormatKVs(Handle arrpass, char[] passchar, char[] cls)
void FormatKVs(Handle passedarr, char[] passchar, char[] cls)
{
	if ((strlen(passchar) > 0) && (StrContains(passchar,"//",false) != 0) && (passedarr != INVALID_HANDLE))
	{
		/*
		Handle passedarr = INVALID_HANDLE;
		if (view_as<int>(arrpass) == 1634494062) passedarr = CreateArray(64);
		else passedarr = CloneArray(arrpass);
		*/
		char kvs[128][256];
		char fmt[256];
		ReplaceStringEx(passchar,256,"	"," ");
		ReplaceString(passchar,256,"	","");
		ExplodeString(passchar," ",kvs,128,256);
		int valdef = -1;
		for (int i = 0;i<64;i++)
		{
			if (StrContains(kvs[i+1],"}",false) == 0)
			{
				break;
			}
			else
			{
				if (StrEqual(kvs[i],"{",false)) i++;
				if ((strlen(kvs[i]) > 0) && (strlen(kvs[i+1]) > 0))
				{
					if ((StrContains(passchar,"values",false) > StrContains(passchar,"classname",false)) && (StrContains(passchar,"classname",false) != -1) && (StrContains(passchar,"edit",false) != -1) && (valdef < 1))
					{
						valdef = StrContains(passchar,"classname",false)+11;
					}
					if ((StrContains(kvs[i],cls,false) != -1) && (StrContains(kvs[i],"for_targetname",false) == -1) && (strlen(cls) > 0))
					{
						i++;
						if ((StrContains(kvs[i],"origin",false) != -1) && (StrContains(kvs[i],"for_origin",false) == -1))
						{
							i+=4;
							//valdef = StrContains(kvs[i],"origin",false)+2;
						}
					}
					if ((StrContains(kvs[i],"values",false) == -1) && (StrContains(kvs[i],"create",false) == -1) && (StrContains(kvs[i],"edit",false) == -1) && (StrContains(kvs[i],"delete",false) == -1) && (StrContains(kvs[i],"modifycase",false) == -1) || ((StrContains(kvs[i],"origin",false) > StrContains(passchar,"values",false)) || (StrContains(kvs[i],"for_origin",false) != -1)))
					{
						char key[128];
						char val[256];
						int set = 0;
						ReplaceString(kvs[i],sizeof(kvs[]),"{","");
						ReplaceString(kvs[i+1],sizeof(kvs[]),"}","");
						if (StrContains(kvs[i],"\"",false) == -1) Format(key,sizeof(key),"%s",kvs[i]);
						else if (StrContains(kvs[i],"\"",false) == 0)
						{
							char tmp[128];
							Format(tmp,sizeof(tmp),"%s",kvs[i]);
							ReplaceStringEx(tmp,sizeof(tmp),"\"","");
							if (StrContains(tmp,"\"",false) > 0)
							{
								Format(key,sizeof(key),"%s",kvs[i]);
							}
						}
						if (StrContains(kvs[i+1],"\"",false) == -1) Format(val,sizeof(val),"%s",kvs[i+1]);
						else if (StrContains(kvs[i+1],"\"",false) == 0)
						{
							char tmp[128];
							Format(tmp,sizeof(tmp),"%s",kvs[i+1]);
							ReplaceStringEx(tmp,sizeof(tmp),"\"","");
							if (StrContains(tmp,"\"",false) > 0)
							{
								Format(val,sizeof(val),"%s",kvs[i+1]);
							}
							else
							{
								for (int j = i+2;j<64;j++)
								{
									Format(kvs[i+1],sizeof(kvs[]),"%s %s",kvs[i+1],kvs[j]);
									if (StrContains(kvs[j],"\"",false) > 0)
									{
										set = j;
										Format(val,sizeof(val),"%s",kvs[i+1]);
										break;
									}
								}
							}
						}
						if ((strlen(key) > 0) && (StrContains(key,"//",false) != 0))
						{
							ReplaceString(key,sizeof(key),"\"","");
							ReplaceString(key,sizeof(key),"{","");
							ReplaceString(key,sizeof(key),"}","");
							if (strlen(val) < 1) Format(val,sizeof(val),"\"\"");
							else
							{
								//ReplaceString(val,sizeof(val),"\"","");
								ReplaceString(val,sizeof(val),"}","");
							}
							if (StrEqual(key,"classname",false))
							{
								if (StrContains(passchar,val,false) <= valdef)
								{
									key = "";
								}
							}
							if (strlen(key) > 0)
							{
								Format(fmt,sizeof(fmt),"%s %s",key,val);
								if (view_as<int>(passedarr) != 1634494062)
								{
									PushArrayString(passedarr,fmt);
								}
								/*
								else
								{
									Handle tmphndl = CreateArray(64);
									passedarr = CloneHandle(tmphndl);
									PushArrayString(passedarr,fmt);
								}
								*/
							}
						}
						if (set == 0) i++;
						else i = set;
					}
				}
			}
		}
		//return passedarr;
		return;
	}
	//return INVALID_HANDLE;
	return;
}

public void dbgch(Handle convar, const char[] oldValue, const char[] newValue)
{
	dbglvl = StringToInt(newValue);
}
