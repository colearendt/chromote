#' Class representing a local Chrome process
#'
#' @export
Chrome <- R6Class("Chrome",
  inherit = Browser,
  public = list(
    initialize = function(path = find_chrome(), args = character(0)) {
      res <- launch_chrome(path, args)
      private$host <- "127.0.0.1"
      private$process <- res$process
      private$port <- res$port
    }
  )
)


find_chrome <- function() {
  if (Sys.getenv("CHROMOTE_CHROME") != "") {
    return(Sys.getenv("CHROMOTE_CHROME"))
  }

  if (is_mac()) {
    "/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome"

  } else if (is_windows()) {
    path <- NULL
    tryCatch(
      {
        path <- readRegistry("SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\chrome.exe\\")
        path <- path[["(Default)"]]
      },
      error = function(e) { }
    )
    path

  } else if (is_linux()) {
    Sys.which("google-chrome")

  } else {
    stop("Platform currently not supported")
  }
}


launch_chrome <- function(path = find_chrome(), args = character(0)) {
  p <- process$new(
    command = path,
    args = c("--headless", "--remote-debugging-port=0", args),
    supervise = TRUE,
    stdout = tempfile("chrome-stdout-", fileext = ".log"),
    stderr = tempfile("chrome-stderr-", fileext = ".log")
  )


  connected <- FALSE
  end <- Sys.time() + 10
  while (!connected && Sys.time() < end) {
    if (!p$is_alive()) {
      stop(
        "Failed to start chrome. Error: ",
        paste(readLines(p$get_error_file()), collapse = "\n")
      )
    }
    tryCatch(
      {
        # Find port number from output
        output <- readLines(p$get_error_file())
        output <- output[grepl("^DevTools listening on ws://", output)]
        if (length(output) != 1) stop() # Just break out of the tryCatch

        port <- sub("^DevTools listening on ws://[0-9\\.]+:(\\d+)/.*", "\\1", output)
        port <- as.integer(port)
        if (is.na(port)) stop()

        con <- url(paste0("http://127.0.0.1:", port, "/json/protocol"), "rb")
        if (!isOpen(con)) break  # Failed to connect

        connected <- TRUE
        close(con)
      },
      warning = function(e) {},
      error = function(e) {}
    )

    Sys.sleep(0.1)
  }

  if (!connected) {
    stop("Chrome debugging port not open after 10 seconds.")
  }

  list(
    process = p,
    port    = port
  )
}


#' Class representing a remote Chrome process
#'
#' @export
ChromeRemote <- R6Class("ChromeRemote",
  inherit = Browser,
  public = list(
    initialize = function(host, port) {
      private$host <- host
      private$port <- port
    }
  )
)
