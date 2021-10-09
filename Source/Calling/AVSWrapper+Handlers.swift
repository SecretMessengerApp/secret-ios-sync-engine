//

import Foundation
import avs

/// Equivalent of `wcall_audio_cbr_change_h`.
typealias ConstantBitRateChangeHandler = @convention(c) (UnsafePointer<Int8>?, Int32, UnsafeMutableRawPointer?) -> Void

/// Equivalent of `wcall_video_state_change_h`.
typealias VideoStateChangeHandler = @convention(c) (UnsafePointer<Int8>?, UnsafePointer<Int8>?, UnsafePointer<Int8>?, Int32, UnsafeMutableRawPointer?) -> Void

/// Equivalent of `wcall_incoming_h`.
typealias IncomingCallHandler = @convention(c) (UnsafePointer<Int8>?, UInt32, UnsafePointer<Int8>?, Int32, Int32, UnsafeMutableRawPointer?) -> Void

/// Equivalent of `wcall_missed_h`.
typealias MissedCallHandler = @convention(c) (UnsafePointer<Int8>?, UInt32, UnsafePointer<Int8>?, Int32, UnsafeMutableRawPointer?) -> Void

/// Equivalent of `wcall_answered_h`.
typealias AnsweredCallHandler = @convention(c) (UnsafePointer<Int8>?, UnsafeMutableRawPointer?) -> Void

/// Equivalent of `wcall_data_chan_estab_h`.
typealias DataChannelEstablishedHandler = @convention(c) (UnsafePointer<Int8>?, UnsafePointer<Int8>?, UnsafeMutableRawPointer?) -> Void

/// Equivalent of `wcall_estab_h`.
typealias CallEstablishedHandler = @convention(c) (UnsafePointer<Int8>?, UnsafePointer<Int8>?, UnsafeMutableRawPointer?) -> Void

/// Equivalent of `wcall_close_h`.
typealias CloseCallHandler = @convention(c) (Int32, UnsafePointer<Int8>?, UInt32, UnsafePointer<Int8>?, UnsafeMutableRawPointer?) -> Void

/// Equivalent of `wcall_metrics_h`.
typealias CallMetricsHandler = @convention(c) (UnsafePointer<Int8>?, UnsafePointer<Int8>?, UnsafeMutableRawPointer?) -> Void

/// Equivalent of `wcall_config_req_h`.
typealias CallConfigRefreshHandler = @convention(c) (UInt32, UnsafeMutableRawPointer?) -> Int32

/// Equivalent of `wcall_ready_h`.
typealias CallReadyHandler = @convention(c) (Int32, UnsafeMutableRawPointer?) -> Void

/// Equivalent of `wcall_send_h`.
typealias CallMessageSendHandler = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<Int8>?, UnsafePointer<Int8>?, UnsafePointer<Int8>?, UnsafePointer<Int8>?, UnsafePointer<Int8>?, UnsafePointer<UInt8>?, Int, Int32, UnsafeMutableRawPointer?) -> Int32

/// Equivalent of `wcall_group_changed_h`.
typealias CallGroupChangedHandler = @convention(c) (UnsafePointer<Int8>?, UnsafeMutableRawPointer?) -> Void

/// Equivalent of `wcall_participant_changed_h`.
typealias CallParticipantChangedHandler = @convention(c) (UnsafePointer<Int8>?, UnsafePointer<Int8>?,  UnsafeMutableRawPointer?) -> Void

/// Equivalent of `wcall_media_stopped_h`.
typealias MediaStoppedChangeHandler = @convention(c) (UnsafePointer<Int8>?, UnsafeMutableRawPointer?) -> Void

/// Equivalent of `wcall_network_quality_h`.
typealias NetworkQualityChangeHandler = @convention(c) (UnsafePointer<Int8>?, UnsafePointer<Int8>?, Int32, Int32, Int32, Int32, UnsafeMutableRawPointer?) -> Void

/// Equivalent of `wcall_set_mute_handler`.
typealias MuteChangeHandler = @convention(c) (Int32, UnsafeMutableRawPointer?) -> Void
