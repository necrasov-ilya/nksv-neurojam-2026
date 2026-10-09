import type { Modifiers } from '../game/upgrades';
export type ActorKind = 'leader'|'walker'|'runner'|'brute'|'bomber'|'spitter'|'civilian'|'athlete'|'heavyCivilian'|'worker'|'medic'|'guard'|'rifleman'|'shotgunner'|'grenadier'|'riot'|'heavy'|'flamer'|'sniper'|'drone'|'sapper';
export interface Actor { id:number; kind:ActorKind; x:number; z:number; y:number; angle:number; hp:number; maxHp:number; state:string; anim:number; attack:number; infected:boolean; timer:number; vx:number; vz:number; cooldown:number; ammo:number; heal:boolean; }
export interface Barrier { id:number;x:number;z:number;hx:number;hz:number;hp:number;maxHp:number;kind:'wood'|'police'|'gate'|'shelter';open:boolean; }
export interface Box { x:number;z:number;hx:number;hz:number; }
export interface Zone { index:number; boxes:Box[]; barriers:Barrier[]; shelters:{x:number;z:number;barrierId:number;opened:boolean}[]; spawn:{x:number;z:number}; exit:{x:number;z:number}; biome:number; weather:number; }
export type EndlessInfo = { sector:number; tier:number; elite:boolean };
export interface Projectile { active:boolean;kind:'grenade'|'acid'|'mortar';x:number;y:number;z:number;vx:number;vy:number;vz:number;timer:number;radius:number;friendly:boolean; }
export interface Effect {kind:'bite'|'infection'|'shot'|'explosion'|'hit'|'debris'|'surge'|'acid';x:number;z:number;y:number;tx?:number;tz?:number;color?:number;}
export interface Cloud { active:boolean;x:number;z:number;radius:number;time:number;tick:number; }
export interface Controls {x:number;z:number;yaw:number;sprint:boolean;dash:boolean;surge:boolean;ability:boolean;select:number;}
export interface RunStats {runTime:number;totalInfected:number;peakHorde:number;humansDefeated:number;sheltersOverrun:number;zombiesLost:number;levelReached:number;}
export interface Snapshot { actors:Actor[]; zone:Zone;projectiles:Projectile[];clouds:Cloud[];leader:Actor;stats:RunStats;mods:Modifiers;time:number;district:number;infection:number;objective:string;readyExit:boolean;xp:number;xpNext:number;level:number;mutation:string;mutationTime:number;surgeCooldown:number;surgeTime:number;dashCooldown:number;abilityCooldown:number;hordeCounts:number[];effects:Effect[];notices:string[];pendingLevel:boolean;won:boolean;lost:boolean;upgrades:string[]; endless:EndlessInfo|undefined; }
export const BIOME_NAMES = ['SUBURBS','DOWNTOWN','POLICE BLOCK','INDUSTRIAL BELT','LAST EVACUATION','WINTER HEIGHTS','ASHEN FIELDS','FROZEN QUARTER','SUNBAKED ROWS','EMBER GROVE','PETROL STATION ROW','HARVEST HILLS','GREEN DISTRICT','CRYO DEPOT','MOLTEN YARD'];
export const WEATHER_NAMES = ['CLEAR','RAIN','SNOW','HEAT HAZE','FOG','ASH FALL'];
