use uuid::Uuid;

/// Magic byte sequence we used to identify Pinput-enabled cartridges.
pub const PINPUT_MAGIC: Uuid = Uuid::from_u128(0x0220c74677ab446ebedc7fd6d277984d);

/// Pinput can fit this many gamepads into the GPIO area.
pub const PINPUT_MAX_GAMEPADS: usize = 8;

/// 60 Hz.
pub static FRAME_DURATION_MS: i64 = 16;

/// 1 Hz between attempts to connect to the runtime.
pub static SCAN_INTERVAL_MS: i64 = 1000;
