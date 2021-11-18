use crate::pico8_connection;

#[derive(thiserror::Error, Debug)]
pub enum Error {
    #[error("SDL error: {0}")]
    SdlStringError(String),

    #[error("SDL error: {0}")]
    SdlError(#[from] sdl2::IntegerOrSdlError),

    #[error("PICO-8 connection error")]
    Pico8Connection(#[from] pico8_connection::Error),

    #[error("Ctrl-C handler error")]
    CtrlC(#[from] ctrlc::Error),

    #[error("Killed by Ctrl-C")]
    KilledByCtrlC,

    #[error("channel error")]
    RecvError(#[from] std::sync::mpsc::RecvError),

    #[error("I/O error")]
    IOError(#[from] std::io::Error),
}