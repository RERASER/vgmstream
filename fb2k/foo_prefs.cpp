#ifdef _MSC_VER
#define _CRT_SECURE_NO_DEPRECATE
#endif
#include <cstring>
#include <stdio.h>
#ifdef _WIN32
#include <io.h>
#endif

#include <foobar2000/SDK/foobar2000.h>

#include "foo_prefs.h"
#include "foo_vgmstream.h"


static cfg_bool     cfg_LoopForever     ({0xa19e36eb,0x72a0,0x4077,{0x91,0x43,0x38,0xb4,0x05,0xfc,0x91,0xc5}}, DEFAULT_LOOP_FOREVER);
static cfg_bool     cfg_IgnoreLoop      ({0xddda7ab6,0x7bb6,0x4abe,{0xb9,0x66,0x2d,0xb7,0x8f,0xe4,0xcc,0xab}}, DEFAULT_IGNORE_LOOP);
static cfg_string   cfg_LoopCount       ({0xfc8dfd72,0xfae8,0x44cc,{0xbe,0x99,0x1c,0x7b,0x27,0x7a,0xb6,0xb9}}, DEFAULT_LOOP_COUNT);
static cfg_string   cfg_FadeLength      ({0x61da7ef1,0x56a5,0x4368,{0xae,0x06,0xec,0x6f,0xd7,0xe6,0x15,0x5d}}, DEFAULT_FADE_SECONDS);
static cfg_string   cfg_FadeDelay       ({0x73907787,0xaf49,0x4659,{0x96,0x8e,0x9f,0x70,0xa1,0x62,0x49,0xc4}}, DEFAULT_FADE_DELAY_SECONDS);
static cfg_bool     cfg_DisableSubsongs ({0xa8cdd664,0xb32b,0x4a36,{0x83,0x07,0xa0,0x4c,0xcd,0x52,0xa3,0x7c}}, DEFAULT_DISABLE_SUBSONGS);
static cfg_string   cfg_DownmixChannels ({0x5a0e65dd,0xeb37,0x4c67,{0x9a,0xb1,0x3f,0xb0,0xc9,0x7e,0xb0,0xe0}}, DEFAULT_DOWNMIX_CHANNELS);
static cfg_bool     cfg_TagfileDisable  ({0xc1971eb7,0xa930,0x4bae,{0x9e,0x7f,0xa9,0x50,0x36,0x32,0x41,0xb3}}, DEFAULT_TAGFILE_DISABLE);
static cfg_bool     cfg_OverrideTitle   ({0xe794831f,0xd067,0x4337,{0x97,0x85,0x10,0x57,0x39,0x4b,0x1b,0x97}}, DEFAULT_OVERRIDE_TITLE);
static cfg_bool     cfg_ExtsUnknownOn   ({0xd92dc6a2,0x9683,0x422d,{0x8e,0xd1,0x59,0x46,0xd5,0xbf,0x01,0x6f}}, DEFAULT_EXTS_UNKNOWN_ON);
static cfg_bool     cfg_ExtsCommonOn    ({0x405af423,0x5037,0x4eae,{0xa6,0xe3,0x72,0xd0,0x12,0x7d,0x84,0x6c}}, DEFAULT_EXTS_COMMON_ON);

static std::string get_cfg_text(cfg_string& cfg) {
    pfc::string8 value = cfg.get();
    return std::string(value.get_ptr());
}

static bool parse_nonnegative_double(const char* value, double* parsed) {
    int consumed = 0;
    double temp = 0.0;
    if (sscanf(value, "%lf%n", &temp, &consumed) < 1)
        return false;
    if (consumed != (int)strlen(value))
        return false;
    if (temp < 0)
        return false;

    if (parsed)
        *parsed = temp;
    return true;
}

static bool parse_nonnegative_int(const char* value, int* parsed) {
    int consumed = 0;
    int temp = 0;
    if (sscanf(value, "%d%n", &temp, &consumed) < 1)
        return false;
    if (consumed != (int)strlen(value))
        return false;
    if (temp < 0)
        return false;

    if (parsed)
        *parsed = temp;
    return true;
}

static bool set_nonnegative_double(cfg_string& cfg, const char* value, const char* field_name, std::string& error) {
    if (!parse_nonnegative_double(value, NULL)) {
        error = std::string("Invalid value for ") + field_name + ". Must be a number greater than or equal to zero.";
        return false;
    }

    cfg = value;
    return true;
}

static bool set_nonnegative_int(cfg_string& cfg, const char* value, const char* field_name, std::string& error) {
    if (!parse_nonnegative_int(value, NULL)) {
        error = std::string("Invalid value for ") + field_name + ". Must be a number greater than or equal to zero.";
        return false;
    }

    cfg = value;
    return true;
}

namespace vgmstream_prefs {
bool get_loop_forever() { return cfg_LoopForever; }
bool get_ignore_loop() { return cfg_IgnoreLoop; }
bool get_disable_subsongs() { return cfg_DisableSubsongs; }
bool get_tagfile_disable() { return cfg_TagfileDisable; }
bool get_override_title() { return cfg_OverrideTitle; }
bool get_exts_unknown_on() { return cfg_ExtsUnknownOn; }
bool get_exts_common_on() { return cfg_ExtsCommonOn; }

std::string get_loop_count_text() { return get_cfg_text(cfg_LoopCount); }
std::string get_fade_length_text() { return get_cfg_text(cfg_FadeLength); }
std::string get_fade_delay_text() { return get_cfg_text(cfg_FadeDelay); }
std::string get_downmix_channels_text() { return get_cfg_text(cfg_DownmixChannels); }

void set_loop_forever(bool value) { cfg_LoopForever = value; }
void set_ignore_loop(bool value) { cfg_IgnoreLoop = value; }
void set_disable_subsongs(bool value) { cfg_DisableSubsongs = value; }
void set_tagfile_disable(bool value) { cfg_TagfileDisable = value; }
void set_override_title(bool value) { cfg_OverrideTitle = value; }
void set_exts_unknown_on(bool value) { cfg_ExtsUnknownOn = value; }
void set_exts_common_on(bool value) { cfg_ExtsCommonOn = value; }

bool set_loop_count_text(const char* value, std::string& error) {
    return set_nonnegative_double(cfg_LoopCount, value, "Loop Count", error);
}

bool set_fade_length_text(const char* value, std::string& error) {
    return set_nonnegative_double(cfg_FadeLength, value, "Fade Length", error);
}

bool set_fade_delay_text(const char* value, std::string& error) {
    return set_nonnegative_double(cfg_FadeDelay, value, "Fade Delay", error);
}

bool set_downmix_channels_text(const char* value, std::string& error) {
    return set_nonnegative_int(cfg_DownmixChannels, value, "Downmix Channels", error);
}

void reset_defaults() {
    cfg_LoopForever = DEFAULT_LOOP_FOREVER;
    cfg_IgnoreLoop = DEFAULT_IGNORE_LOOP;
    cfg_LoopCount = DEFAULT_LOOP_COUNT;
    cfg_FadeLength = DEFAULT_FADE_SECONDS;
    cfg_FadeDelay = DEFAULT_FADE_DELAY_SECONDS;
    cfg_DisableSubsongs = DEFAULT_DISABLE_SUBSONGS;
    cfg_DownmixChannels = DEFAULT_DOWNMIX_CHANNELS;
    cfg_TagfileDisable = DEFAULT_TAGFILE_DISABLE;
    cfg_OverrideTitle = DEFAULT_OVERRIDE_TITLE;
    cfg_ExtsUnknownOn = DEFAULT_EXTS_UNKNOWN_ON;
    cfg_ExtsCommonOn = DEFAULT_EXTS_COMMON_ON;
}
}

// Needs to be here in rder to access the static config
void input_vgmstream::load_settings() {
    pfc::string8 fade_length = cfg_FadeLength.get();
    pfc::string8 loop_count_text = cfg_LoopCount.get();
    pfc::string8 fade_delay = cfg_FadeDelay.get();
    pfc::string8 downmix_channels_text = cfg_DownmixChannels.get();

	// no verification needed here, as it is done below
	sscanf(fade_length.get_ptr(), "%lf", &fade_seconds);
	sscanf(loop_count_text.get_ptr(), "%lf", &loop_count);
	sscanf(fade_delay.get_ptr(), "%lf", &fade_delay_seconds);
	loop_forever = cfg_LoopForever;
	ignore_loop = cfg_IgnoreLoop;
    disable_subsongs = cfg_DisableSubsongs;
    sscanf(downmix_channels_text.get_ptr(), "%d", &downmix_channels);
    tagfile_disable = cfg_TagfileDisable;
    override_title = cfg_OverrideTitle;
  //exts_unknown_on = cfg_ExtsUnknownOn;
  //exts_common_on = cfg_ExtsCommonOn;

    /* exact 0 was allowed before (AKA "intro only") but confuses people and may result in unplayable files */
    if (loop_count <= 0)
        loop_count = 1;
}

void input_vgmstream::g_load_cfg(bool* accept_unknown, bool* accept_common) {
    //TODO improve
    *accept_unknown = cfg_ExtsUnknownOn;
    *accept_common = cfg_ExtsCommonOn;
}

#ifdef _WIN32
const char* vgmstream_prefs::get_name() {
	return input_vgmstream::g_get_name();
}

GUID vgmstream_prefs::get_guid() {
	return input_vgmstream::g_get_preferences_guid();
}

GUID vgmstream_prefs::get_parent_guid() {
	return guid_input;
}

static UINT get_check(bool value) {
	return value ? BST_CHECKED : BST_UNCHECKED;
}

BOOL vgmstreamPreferences::OnInitDialog(CWindow, LPARAM) {
	CheckDlgButton(IDC_LOOP_FOREVER, get_check(cfg_LoopForever));
	CheckDlgButton(IDC_IGNORE_LOOP, get_check(cfg_IgnoreLoop));
	CheckDlgButton(IDC_LOOP_NORMALLY, get_check(!cfg_IgnoreLoop && !cfg_LoopForever));

	uSetDlgItemText(m_hWnd, IDC_LOOP_COUNT, cfg_LoopCount);
	uSetDlgItemText(m_hWnd, IDC_FADE_SECONDS, cfg_FadeLength);
	uSetDlgItemText(m_hWnd, IDC_FADE_DELAY_SECONDS, cfg_FadeDelay);

	CheckDlgButton(IDC_DISABLE_SUBSONGS, get_check(cfg_DisableSubsongs));

    uSetDlgItemText(m_hWnd, IDC_DOWNMIX_CHANNELS, cfg_DownmixChannels);

    CheckDlgButton(IDC_TAGFILE_DISABLE, get_check(cfg_TagfileDisable));
    CheckDlgButton(IDC_OVERRIDE_TITLE, get_check(cfg_OverrideTitle));
    CheckDlgButton(IDC_EXTS_UNKNOWN_ON, get_check(cfg_ExtsUnknownOn));
    CheckDlgButton(IDC_EXTS_COMMON_ON, get_check(cfg_ExtsCommonOn));

	m_darkhooks.AddDialogWithControls(m_hWnd);

	return TRUE;
}

t_uint32 vgmstreamPreferences::get_state() {
	t_uint32 state = preferences_state::resettable | preferences_state::dark_mode_supported;
	if (HasChanged())
		state |= preferences_state::changed;
	return state;
}

void vgmstreamPreferences::reset() {
	CheckDlgButton(IDC_LOOP_FOREVER, get_check(DEFAULT_LOOP_FOREVER));
	CheckDlgButton(IDC_IGNORE_LOOP, get_check(DEFAULT_IGNORE_LOOP));
	CheckDlgButton(IDC_LOOP_NORMALLY, get_check(!DEFAULT_IGNORE_LOOP && !DEFAULT_LOOP_FOREVER));

	uSetDlgItemText(m_hWnd, IDC_LOOP_COUNT, DEFAULT_LOOP_COUNT);
	uSetDlgItemText(m_hWnd, IDC_FADE_SECONDS, DEFAULT_FADE_SECONDS);
	uSetDlgItemText(m_hWnd, IDC_FADE_DELAY_SECONDS, DEFAULT_FADE_DELAY_SECONDS);

    CheckDlgButton(IDC_DISABLE_SUBSONGS, get_check(DEFAULT_DISABLE_SUBSONGS));

    uSetDlgItemText(m_hWnd, IDC_DOWNMIX_CHANNELS, DEFAULT_DOWNMIX_CHANNELS);

    CheckDlgButton(IDC_TAGFILE_DISABLE, get_check(DEFAULT_TAGFILE_DISABLE));
    CheckDlgButton(IDC_OVERRIDE_TITLE, get_check(DEFAULT_OVERRIDE_TITLE));
    CheckDlgButton(IDC_EXTS_UNKNOWN_ON, get_check(DEFAULT_EXTS_UNKNOWN_ON));
    CheckDlgButton(IDC_EXTS_COMMON_ON, get_check(DEFAULT_EXTS_COMMON_ON));
}


void vgmstreamPreferences::apply() {
	cfg_LoopForever = IsDlgButtonChecked(IDC_LOOP_FOREVER)?true:false;
	cfg_IgnoreLoop = IsDlgButtonChecked(IDC_IGNORE_LOOP)?true:false;
    cfg_DisableSubsongs = IsDlgButtonChecked(IDC_DISABLE_SUBSONGS)?true:false;
    cfg_TagfileDisable = IsDlgButtonChecked(IDC_TAGFILE_DISABLE)?true:false;
    cfg_OverrideTitle = IsDlgButtonChecked(IDC_OVERRIDE_TITLE)?true:false;
    cfg_ExtsUnknownOn = IsDlgButtonChecked(IDC_EXTS_UNKNOWN_ON)?true:false;
    cfg_ExtsCommonOn = IsDlgButtonChecked(IDC_EXTS_COMMON_ON)?true:false;

	double temp_fade_seconds;
	double temp_fade_delay_seconds;
	double temp_loop_count;
	int consumed;
    int temp_downmix_channels;

	pfc::string buf;
	buf = uGetDlgItemText(m_hWnd, IDC_FADE_SECONDS);
	if (sscanf(buf.get_ptr(), "%lf%n", &temp_fade_seconds, &consumed) < 1
		|| consumed != strlen(buf.get_ptr()) || temp_fade_seconds < 0) {
		uMessageBox(m_hWnd,
				"Invalid value for Fade Length\n"
				"Must be a number greater than or equal to zero",
				"Error",MB_OK|MB_ICONERROR);
		return;
	} else cfg_FadeLength = buf.get_ptr();

	buf = uGetDlgItemText(m_hWnd, IDC_LOOP_COUNT);
	if (sscanf(buf.get_ptr(), "%lf%n", &temp_loop_count, &consumed) < 1
		|| consumed != strlen(buf.get_ptr()) || temp_loop_count < 0) {
		uMessageBox(m_hWnd,
				"Invalid value for Loop Count\n"
				"Must be a number greater than or equal to zero",
				"Error",MB_OK|MB_ICONERROR);
		return;
	} else cfg_LoopCount = buf.get_ptr();

	buf = uGetDlgItemText(m_hWnd, IDC_FADE_DELAY_SECONDS);
	if (sscanf(buf.get_ptr(), "%lf%n", &temp_fade_delay_seconds, &consumed) < 1
		|| consumed != strlen(buf.get_ptr()) || temp_fade_delay_seconds < 0) {
		uMessageBox(m_hWnd,
				"Invalid value for Fade Delay\n"
				"Must be a number",
				"Error", MB_OK|MB_ICONERROR);
		return;
	} else cfg_FadeDelay = buf.get_ptr();

    buf = uGetDlgItemText(m_hWnd, IDC_DOWNMIX_CHANNELS);
    if (sscanf(buf.get_ptr(), "%d%n", &temp_downmix_channels, &consumed) < 1
        || consumed != strlen(buf.get_ptr()) || temp_downmix_channels < 0) {
        uMessageBox(m_hWnd,
                "Invalid value for Downmix Channels\n"
                "Must be a number greater than or equal to zero",
                "Error", MB_OK|MB_ICONERROR);
        return;
    } else cfg_DownmixChannels = buf.get_ptr();

}


bool vgmstreamPreferences::HasChanged() {

	if(IsDlgButtonChecked(IDC_LOOP_FOREVER))
		if(cfg_LoopForever != true) return true;

	if(IsDlgButtonChecked(IDC_IGNORE_LOOP))
		if(cfg_IgnoreLoop != true) return true;

	if(IsDlgButtonChecked(IDC_LOOP_NORMALLY))
		if(cfg_IgnoreLoop != false || cfg_LoopForever != false) return true;

    bool current;

    current = IsDlgButtonChecked(IDC_DISABLE_SUBSONGS)?true:false;
    if(cfg_DisableSubsongs != current) return true;

    current = IsDlgButtonChecked(IDC_TAGFILE_DISABLE)?true:false;
    if(cfg_TagfileDisable != current) return true;

    current = IsDlgButtonChecked(IDC_OVERRIDE_TITLE)?true:false;
    if(cfg_OverrideTitle != current) return true;

    current = IsDlgButtonChecked(IDC_EXTS_UNKNOWN_ON)?true:false;
    if(cfg_ExtsUnknownOn != current) return true;

    current = IsDlgButtonChecked(IDC_EXTS_COMMON_ON)?true:false;
    if(cfg_ExtsCommonOn != current) return true;

	pfc::string FadeLength(cfg_FadeLength);
	pfc::string FadeDelay(cfg_FadeDelay);
	pfc::string LoopCount(cfg_LoopCount);

	if(FadeLength != uGetDlgItemText(m_hWnd, IDC_FADE_SECONDS)) return true;
	if(FadeDelay != uGetDlgItemText(m_hWnd, IDC_FADE_DELAY_SECONDS)) return true;
	if(LoopCount != uGetDlgItemText(m_hWnd, IDC_LOOP_COUNT)) return true;

    pfc::string DownmixChannels(cfg_DownmixChannels);
    if(DownmixChannels != uGetDlgItemText(m_hWnd, IDC_DOWNMIX_CHANNELS)) return true;

	return FALSE;
}


void vgmstreamPreferences::OnEditChange(UINT, int, CWindow) {
	m_callback->on_state_changed();
}


static preferences_page_factory_t<vgmstream_prefs> g_vgmstream_preferences_page_factory;
#endif
