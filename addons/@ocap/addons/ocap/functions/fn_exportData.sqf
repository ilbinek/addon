#include "script_macros.hpp"
if (!ocap_capture) exitWith {LOG(["fnc_exportData.sqf called, but recording hasn't started."]);};

[] spawn {
	_realyTime = time - ocap_startTime;
	_ocapTime = ocap_frameCaptureDelay * ocap_captureFrameNo;
	LOG(ARR6("fnc_exportData.sqf: RealyTime =", _realyTime," OcapTime =", _ocapTime," delta =", _realyTime - _OcapTime));
};

ocap_capture = false;
ocap_endFrameNo = ocap_captureFrameNo;

publicVariable "ocap_endFrameNo";

params ["_side", "_message", "_tag"];
switch (count _this) do {
	case 0: {
		[":EVENT:", [ocap_endFrameNo, "endMission", ["", "Mission ended"]]] call ocap_fnc_extension;
	};
	case 1: {
		[":EVENT:", [ocap_endFrameNo, "endMission", ["", _side]]] call ocap_fnc_extension;
	};
	default {
		private _sideString = str(_side);
		if (_side == sideUnknown) then { _sideString = "" };
		[":EVENT:", [ocap_endFrameNo, "endMission", [_sideString, _message]]] call ocap_fnc_extension;
	};
};

if (ocap_needToSave) then {
	if (!isNil "_tag") then {
		[":SAVE:", [worldName, briefingName, getMissionConfigValue ["author", ""], ocap_frameCaptureDelay, ocap_endFrameNo, _tag]] call ocap_fnc_extension;
		LOG(ARR4("Saved recording of mission", briefingName, "with tag", _tag));
	} else {
		[":SAVE:", [worldName, briefingName, getMissionConfigValue ["author", ""], ocap_frameCaptureDelay, ocap_endFrameNo]] call ocap_fnc_extension;
		LOG(ARR3("Saved recording of mission", briefingName, "with default tag"));
	};

	{
		player createDiaryRecord [
			"OCAP2Info",
			[
				"Status",
				(
					"OCAP2 capture of " + briefingName + " has been exported with " + str(ocap_endFrameNo) + " frames saved." +
					"<br/><br/>" +
					"Upload results have been logged."
				)
			]
		];
		player setDiarySubjectPicture [
			"OCAP2Info",
			"\A3\ui_f\data\igui\cfg\simpleTasks\types\upload_ca.paa"
		];
	} remoteExec ["call", 0, true];
} else {
	LOG(["ocap_needToSave is set to false. Not saving"]);
	{
		player createDiaryRecord [
			"OCAP2Info",
			[
				"Status",
				(
					"OCAP2 capture of " + briefingName + " has not been saved, as the configured criteria have not been met." +
				)
			]
		];
		player setDiarySubjectPicture [
			"OCAP2Info",
			"\A3\ui_f\data\igui\cfg\simpleTasks\types\danger_ca.paa"
		];
	} remoteExec ["call", 0, true];
};
