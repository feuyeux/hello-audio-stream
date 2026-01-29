use chrono::Local;

static mut VERBOSE: bool = false;

pub fn init(verbose: bool) {
    unsafe {
        VERBOSE = verbose;
    }
}

fn is_verbose() -> bool {
    unsafe { VERBOSE }
}

fn format_timestamp() -> String {
    Local::now().format("%Y-%m-%d %H:%M:%S%.3f").to_string()
}

pub fn log_debug(message: &str) {
    if is_verbose() {
        println!("[{}] [debug] {}", format_timestamp(), message);
    }
}

pub fn log_info(message: &str) {
    println!("[{}] [info] {}", format_timestamp(), message);
}

pub fn log_warn(message: &str) {
    println!("[{}] [warn] {}", format_timestamp(), message);
}

pub fn log_error(message: &str) {
    eprintln!("[{}] [error] {}", format_timestamp(), message);
}

pub fn log_phase(phase: &str) {
    println!();
    println!("[{}] [info] === {} ===", format_timestamp(), phase);
}
