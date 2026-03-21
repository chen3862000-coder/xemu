#if !USE_XEMU_CORES
import Foundation
#if canImport(XemuCoresLib)
import XemuCoresLib

private let stubVideoBuffer = xemu_video_buffer_t(data: nil, width: 0, height: 0, pitch: 0)
private let stubAudioBuffer = xemu_audio_buffer_t(data: nil, sample_count: 0, sample_rate: 44_100)

@_cdecl("xemu_error_string")
func xemu_error_string_stub(_ error: xemu_error_t) -> UnsafePointer<CChar>? {
    ("stub" as NSString).utf8String
}

@_cdecl("xemu_gb_create")
func xemu_gb_create_stub() -> xemu_gb_handle_t? { OpaquePointer(bitPattern: 0x1) }

@_cdecl("xemu_gb_destroy")
func xemu_gb_destroy_stub(_ handle: xemu_gb_handle_t?) {}

@_cdecl("xemu_gb_load_rom")
func xemu_gb_load_rom_stub(_ handle: xemu_gb_handle_t?, _ filename: UnsafePointer<CChar>?, _ data: UnsafePointer<UInt8>?, _ size: Int) -> xemu_error_t { XEMU_OK }

@_cdecl("xemu_gb_unload_rom")
func xemu_gb_unload_rom_stub(_ handle: xemu_gb_handle_t?) -> xemu_error_t { XEMU_OK }

@_cdecl("xemu_gb_is_rom_loaded")
func xemu_gb_is_rom_loaded_stub(_ handle: xemu_gb_handle_t?) -> Int32 { 0 }

@_cdecl("xemu_gb_run_frame")
func xemu_gb_run_frame_stub(_ handle: xemu_gb_handle_t?) -> xemu_error_t { XEMU_OK }

@_cdecl("xemu_gb_reset")
func xemu_gb_reset_stub(_ handle: xemu_gb_handle_t?) -> xemu_error_t { XEMU_OK }

@_cdecl("xemu_gb_get_video_buffer")
func xemu_gb_get_video_buffer_stub(_ handle: xemu_gb_handle_t?) -> xemu_video_buffer_t { stubVideoBuffer }

@_cdecl("xemu_gb_get_audio_buffer")
func xemu_gb_get_audio_buffer_stub(_ handle: xemu_gb_handle_t?) -> xemu_audio_buffer_t { stubAudioBuffer }

@_cdecl("xemu_gb_set_input")
func xemu_gb_set_input_stub(_ handle: xemu_gb_handle_t?, _ buttons: UInt32) {}

@_cdecl("xemu_gb_get_save_state_size")
func xemu_gb_get_save_state_size_stub(_ handle: xemu_gb_handle_t?) -> Int { 0 }

@_cdecl("xemu_gb_save_state")
func xemu_gb_save_state_stub(_ handle: xemu_gb_handle_t?, _ state: UnsafeMutablePointer<xemu_save_state_t>?) -> xemu_error_t { XEMU_OK }

@_cdecl("xemu_gb_load_state")
func xemu_gb_load_state_stub(_ handle: xemu_gb_handle_t?, _ state: UnsafePointer<xemu_save_state_t>?) -> xemu_error_t { XEMU_OK }

@_cdecl("xemu_gb_get_battery_save_size")
func xemu_gb_get_battery_save_size_stub(_ handle: xemu_gb_handle_t?) -> Int { 0 }

@_cdecl("xemu_gb_save_battery")
func xemu_gb_save_battery_stub(_ handle: xemu_gb_handle_t?, _ battery: UnsafeMutablePointer<xemu_save_state_t>?) -> xemu_error_t { XEMU_OK }

@_cdecl("xemu_gb_load_battery")
func xemu_gb_load_battery_stub(_ handle: xemu_gb_handle_t?, _ battery: UnsafePointer<xemu_save_state_t>?) -> xemu_error_t { XEMU_OK }

@_cdecl("xemu_gb_is_cgb_mode")
func xemu_gb_is_cgb_mode_stub(_ handle: xemu_gb_handle_t?) -> Int32 { 0 }

@_cdecl("xemu_gba_create")
func xemu_gba_create_stub() -> xemu_gba_handle_t? { OpaquePointer(bitPattern: 0x2) }

@_cdecl("xemu_gba_destroy")
func xemu_gba_destroy_stub(_ handle: xemu_gba_handle_t?) {}

@_cdecl("xemu_gba_load_rom")
func xemu_gba_load_rom_stub(_ handle: xemu_gba_handle_t?, _ filename: UnsafePointer<CChar>?, _ data: UnsafePointer<UInt8>?, _ size: Int) -> xemu_error_t { XEMU_OK }

@_cdecl("xemu_gba_unload_rom")
func xemu_gba_unload_rom_stub(_ handle: xemu_gba_handle_t?) -> xemu_error_t { XEMU_OK }

@_cdecl("xemu_gba_is_rom_loaded")
func xemu_gba_is_rom_loaded_stub(_ handle: xemu_gba_handle_t?) -> Int32 { 0 }

@_cdecl("xemu_gba_run_frame")
func xemu_gba_run_frame_stub(_ handle: xemu_gba_handle_t?) -> xemu_error_t { XEMU_OK }

@_cdecl("xemu_gba_reset")
func xemu_gba_reset_stub(_ handle: xemu_gba_handle_t?) -> xemu_error_t { XEMU_OK }

@_cdecl("xemu_gba_get_video_buffer")
func xemu_gba_get_video_buffer_stub(_ handle: xemu_gba_handle_t?) -> xemu_video_buffer_t { stubVideoBuffer }

@_cdecl("xemu_gba_get_audio_buffer")
func xemu_gba_get_audio_buffer_stub(_ handle: xemu_gba_handle_t?) -> xemu_audio_buffer_t { stubAudioBuffer }

@_cdecl("xemu_gba_set_input")
func xemu_gba_set_input_stub(_ handle: xemu_gba_handle_t?, _ buttons: UInt32) {}

@_cdecl("xemu_gba_get_save_state_size")
func xemu_gba_get_save_state_size_stub(_ handle: xemu_gba_handle_t?) -> Int { 0 }

@_cdecl("xemu_gba_save_state")
func xemu_gba_save_state_stub(_ handle: xemu_gba_handle_t?, _ state: UnsafeMutablePointer<xemu_save_state_t>?) -> xemu_error_t { XEMU_OK }

@_cdecl("xemu_gba_load_state")
func xemu_gba_load_state_stub(_ handle: xemu_gba_handle_t?, _ state: UnsafePointer<xemu_save_state_t>?) -> xemu_error_t { XEMU_OK }

@_cdecl("xemu_gba_get_battery_save_size")
func xemu_gba_get_battery_save_size_stub(_ handle: xemu_gba_handle_t?) -> Int { 0 }

@_cdecl("xemu_gba_save_battery")
func xemu_gba_save_battery_stub(_ handle: xemu_gba_handle_t?, _ battery: UnsafeMutablePointer<xemu_save_state_t>?) -> xemu_error_t { XEMU_OK }

@_cdecl("xemu_gba_load_battery")
func xemu_gba_load_battery_stub(_ handle: xemu_gba_handle_t?, _ battery: UnsafePointer<xemu_save_state_t>?) -> xemu_error_t { XEMU_OK }

@_cdecl("xemu_gba_read_memory8")
func xemu_gba_read_memory8_stub(_ handle: xemu_gba_handle_t?, _ address: UInt32, _ value: UnsafeMutablePointer<UInt8>?) -> xemu_error_t {
    value?.pointee = 0
    return XEMU_OK
}

@_cdecl("xemu_gba_read_memory16")
func xemu_gba_read_memory16_stub(_ handle: xemu_gba_handle_t?, _ address: UInt32, _ value: UnsafeMutablePointer<UInt16>?) -> xemu_error_t {
    value?.pointee = 0
    return XEMU_OK
}

@_cdecl("xemu_gba_read_memory32")
func xemu_gba_read_memory32_stub(_ handle: xemu_gba_handle_t?, _ address: UInt32, _ value: UnsafeMutablePointer<UInt32>?) -> xemu_error_t {
    value?.pointee = 0
    return XEMU_OK
}

@_cdecl("xemu_nds_create")
func xemu_nds_create_stub() -> xemu_nds_handle_t? { OpaquePointer(bitPattern: 0x3) }

@_cdecl("xemu_nds_destroy")
func xemu_nds_destroy_stub(_ handle: xemu_nds_handle_t?) {}

@_cdecl("xemu_nds_load_rom")
func xemu_nds_load_rom_stub(_ handle: xemu_nds_handle_t?, _ filename: UnsafePointer<CChar>?, _ data: UnsafePointer<UInt8>?, _ size: Int) -> xemu_error_t { XEMU_OK }

@_cdecl("xemu_nds_unload_rom")
func xemu_nds_unload_rom_stub(_ handle: xemu_nds_handle_t?) -> xemu_error_t { XEMU_OK }

@_cdecl("xemu_nds_is_rom_loaded")
func xemu_nds_is_rom_loaded_stub(_ handle: xemu_nds_handle_t?) -> Int32 { 0 }

@_cdecl("xemu_nds_run_frame")
func xemu_nds_run_frame_stub(_ handle: xemu_nds_handle_t?) -> xemu_error_t { XEMU_OK }

@_cdecl("xemu_nds_reset")
func xemu_nds_reset_stub(_ handle: xemu_nds_handle_t?) -> xemu_error_t { XEMU_OK }

@_cdecl("xemu_nds_get_video_buffer")
func xemu_nds_get_video_buffer_stub(_ handle: xemu_nds_handle_t?) -> xemu_video_buffer_t { stubVideoBuffer }

@_cdecl("xemu_nds_get_audio_buffer")
func xemu_nds_get_audio_buffer_stub(_ handle: xemu_nds_handle_t?) -> xemu_audio_buffer_t { stubAudioBuffer }

@_cdecl("xemu_nds_set_input")
func xemu_nds_set_input_stub(_ handle: xemu_nds_handle_t?, _ buttons: UInt32) {}

@_cdecl("xemu_nds_set_touch")
func xemu_nds_set_touch_stub(_ handle: xemu_nds_handle_t?, _ touch: xemu_nds_touch_state_t) {}

@_cdecl("xemu_nds_get_save_state_size")
func xemu_nds_get_save_state_size_stub(_ handle: xemu_nds_handle_t?) -> Int { 0 }

@_cdecl("xemu_nds_save_state")
func xemu_nds_save_state_stub(_ handle: xemu_nds_handle_t?, _ state: UnsafeMutablePointer<xemu_save_state_t>?) -> xemu_error_t { XEMU_OK }

@_cdecl("xemu_nds_load_state")
func xemu_nds_load_state_stub(_ handle: xemu_nds_handle_t?, _ state: UnsafePointer<xemu_save_state_t>?) -> xemu_error_t { XEMU_OK }

@_cdecl("xemu_nds_set_screen_layout")
func xemu_nds_set_screen_layout_stub(_ handle: xemu_nds_handle_t?, _ layout: xemu_nds_screen_layout_t) -> xemu_error_t { XEMU_OK }

@_cdecl("xemu_nds_get_screen_layout")
func xemu_nds_get_screen_layout_stub(_ handle: xemu_nds_handle_t?) -> xemu_nds_screen_layout_t { XEMU_NDS_SCREEN_LAYOUT_STACKED }
#endif
#endif
