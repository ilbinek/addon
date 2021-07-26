#include "\userconfig\ocap\config.hpp"
#include "script_macros.hpp"

private _isKindOfApc = {
	_bool = false;
	{
		if (_this isKindOf _x) exitWith {_bool = true;};false
	} count ["Wheeled_APC_F","Tracked_APC","APC_Wheeled_01_base_F","APC_Wheeled_02_base_F",
	"APC_Wheeled_03_base_F","APC_Tracked_01_base_F","APC_Tracked_02_base_F","APC_Tracked_03_base_F"];
	_bool
};
private _getClass = {
	if (_this isKindOf "Truck_F") exitWith {"truck"}; // Should be higher than Car
	if (_this call _isKindOfApc) exitWith {"apc"};
	if (_this isKindOf "Car") exitWith {"car"};
	if (_this isKindOf "Tank") exitWith {"tank"};
	if (_this isKindOf "StaticMortar") exitWith {"static-mortar"};
	if (_this isKindOf "StaticWeapon") exitWith {"static-weapon"};
	if (_this isKindOf "ParachuteBase") exitWith {"parachute"};
	if (_this isKindOf "Helicopter") exitWith {"heli"};
	if (_this isKindOf "Plane") exitWith {"plane"};
	if (_this isKindOf "Air") exitWith {"plane"};
	if (_this isKindOf "Ship") exitWith {"sea"};
	"unknown"
};

waitUntil{(count(allPlayers) >= ocap_minPlayerCount)};
ocap_capture = true;
ocap_startTime = time;
LOG(ARR3(__FILE__, "ocap_capture start, time:", ocap_startTime));

[{
	player createDiaryRecord [
		"OCAP2Info",
		[
			"Status",
			"OCAP2 recording conditions met -- beginning capture."
		]
	];
	player setDiarySubjectPicture [
		"OCAP2Info",
		"\A3\ui_f\data\igui\cfg\simpleTasks\types\use_ca.paa"
	];
}] remoteExec ["call", 0, true];


[] call ocap_fnc_updateTime;

private _id = 0;
while {ocap_capture} do {
	isNil {
		if (ocap_captureFrameNo == 10 || (ocap_captureFrameNo > 10 && ocap_trackTimes && ocap_captureFrameNo % ocap_trackTimeInterval == 0)) then {
			[] call ocap_fnc_updateTime;
		};

		if (ocap_captureFrameNo % 60 == 0) then {
			publicVariable "ocap_captureFrameNo";
			{
				player createDiaryRecord [
					"OCAP2Info",
					[
						"Status",
						("Capture frame: " + str(ocap_captureFrameNo))
					]
				];
			} remoteExecCall ["call", 0, true];
		};

		{
			if !(_x getVariable ["ocap_isInitialised", false]) then {
				if (_x isKindOf "Logic") exitWith {
					_x setVariable ["ocap_exclude", true];
					_x setVariable ["ocap_isInitialised", true];
				};
				_x setVariable ["ocap_id", _id];
				[":NEW:UNIT:", [
					ocap_captureFrameNo, //1
					_id, //2
					name _x, //3
					groupID (group _x), //4
					str side group _x, //5
					BOOL(isPlayer _x), //6
					roleDescription _x // 7
				]] call ocap_fnc_extension;
				[_x] spawn ocap_fnc_addEventHandlers;
				_id = _id + 1;
				_x setVariable ["ocap_isInitialised", true];
			};
			if !(_x getVariable ["ocap_exclude", false]) then {
				private _unitRole = _x getVariable ["ocap_unitType", ""];
				if (ocap_captureFrameNo % 10 == 0 || _unitRole == "") then {
					_unitRole = [_x] call ocap_fnc_getUnitType;
					_x setVariable ["ocap_unitType", _unitRole];
				};

				private _lifeState = 0;
				if (alive _x) then {
					if (ocap_preferACEUnconscious && !isNil "ace_common_fnc_isAwake") then {
						_lifeState = if ([_x] call ace_common_fnc_isAwake) then {1} else {2};
					} else {
						_lifeState = if (lifeState _x isEqualTo "INCAPACITATED") then {2} else {1};
					};
				};

				_pos = getPosATL _x;
				_pos resize 2;
				[":UPDATE:UNIT:", [
					(_x getVariable "ocap_id"), //1
					_pos, //2
					round getDir _x, //3
					_lifeState, //4
					BOOL(!((vehicle _x) isEqualTo _x)),  //5
					if (alive _x) then {name _x} else {""}, //6
					BOOL(isPlayer _x), //7
					_unitRole //8
				]] call ocap_fnc_extension;
			};
			false
		} count (allUnits + allDeadMen);

		{
			if !(_x getVariable ["ocap_isInitialised", false]) then {
				_vehType = typeOf _x;
				_class = _vehType call _getClass;
				if ((_class isEqualTo "unknown") || (_vehType in ocap_excludeClassFromRecord)) exitWith {
					LOG(ARR2("WARNING: vehicle is defined as 'unknown' or exclude:", _vehType));
					_x setVariable ["ocap_isInitialised", true];
					_x setVariable ["ocap_exclude", true];
				};
				_x setVariable ["ocap_id", _id];
				[":NEW:VEH:", [
					ocap_captureFrameNo, //1
					_id, //2
					_class, //3
					getText (configFile >> "CfgVehicles" >> _vehType >> "displayName") //4
				]] call ocap_fnc_extension;
				[_x] spawn ocap_fnc_addEventHandlers;
				_id = _id + 1;
				_x setVariable ["ocap_isInitialised", true];
			};
			if !(_x getVariable ["ocap_exclude", false]) then {
				private _crew = [];
				{
					if (_x getVariable ["ocap_isInitialised", false]) then {
						_crew pushBack (_x getVariable "ocap_id");
					}; false
				} count (crew _x);
				_pos = getPosATL _x;
				_pos set [2, round(_pos select 2)];
				[":UPDATE:VEH:", [
					(_x getVariable "ocap_id"), //1
					_pos, //2
					round getDir _x, //3
					BOOL(alive _x), //4
					_crew, //5
					ocap_captureFrameNo // 6
				]] call ocap_fnc_extension;
			};
			false
		} count vehicles;
	};
	sleep (call ocap_fnc_getDelay);
	ocap_captureFrameNo = ocap_captureFrameNo + 1;
};
