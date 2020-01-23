using LibSerialPort

function cmd(port::SerialPort, query)
  write(port, query * "\r")
  resp = strip(readuntil(port, '\n'), ['\r', '\n', '\0'])
  if resp != "OK"
    println("got error from plotter: " * repr(resp))
    @assert false
  end
end

function query(port::SerialPort, query)
  write(port, query * "\r")
  strip(readuntil(port, '\n'))
end

struct Board
  port::SerialPort
  speedUp::Int
  speedDown::Int

  function Board(port)
    board = new(port, 50, 75)
    setspeed(board, 50, 75)
    board
  end
end

function setspeed(board::Board, speed::Int)
  setspeed(board, speed, speed)
end

function setspeed(board::Board, speedDown::Int, speedUp::Int)
  # Servo speed units (as set with setPenUpRate) are units of %/second,
  # referring to the percentages above.
  # The EBB takes speeds in units of 1/(12 MHz) steps
  # per 24 ms.  Scaling as above, 1% of range in 1 second
  # with SERVO_MAX = 27831 and SERVO_MIN = 9855
  # corresponds to 180 steps change in 1 s
  # That gives 0.180 steps/ms, or 4.5 steps / 24 ms.

  @assert 1 <= speedDown <= 200
  @assert 1 <= speedUp <= 200

  # Our input range (1-100%) corresponds to speeds up to
  # 100% range in 0.25 seconds, or 4 * 4.5 = 18 steps/24 ms.
  cmd(board.port, "SC,11," * string(speedUp))
  cmd(board.port, "SC,12," * string(speedDown))
end

println("connecting...")
port = open("/dev/cu.usbmodem14101", 30000)
board = Board(port)
println(query(port, "SP,0"))
println(query(port, "SP,1"))
