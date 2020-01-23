using LibSerialPort

SERVO_MAX = 27831  # Highest allowed position; "100%" on the scale.    Default value: 25200 units, or 2.31 ms.
SERVO_MIN = 9855   # Lowest allowed position; "0%" on the scale.       Default value: 10800 units, or 0.818 ms.
SERVO_RANGE = SERVO_MAX-SERVO_MIN # 17976
SERVO_FASTEST_TIME = 0.25 # minimum time in seconds to go from SERVO_MIN to SERVO_MAX

function cmd(port::SerialPort, query)
  write(port, query * "\r")
  resp = replace(readuntil(port, '\n'), ['\r', '\n', '\0'] => "")
  if resp != "OK"
    println("got error from plotter: " * repr(resp) * " when sending command: " * repr(query))
    @assert false
  end
end

function query(port::SerialPort, query)
  write(port, query * "\r")
  strip(readuntil(port, '\n'))
end

mutable struct Plotter
  port::SerialPort
  speedUp::Int
  speedDown::Int
  posUp::Int
  posDown::Int
  penIsDown::Bool

  function Plotter(portPath)
    port = open(portPath, 10000)
    plotter = new(port, 0, 0, 0, 0, true)
    setspeed(plotter, 50, 75)
    setpenpos(plotter, 40, 60)
    penup(plotter)
    plotter
  end
end

function setpenpos(plotter::Plotter, posDown::Int, posUp::Int)
  @assert 0 <= posDown <= 100
  @assert 0 <= posUp <= 100

  slope = SERVO_RANGE / 100

  cmd(plotter.port, "SC,4," * string(trunc(Int, SERVO_MIN + posUp * slope)))
  cmd(plotter.port, "SC,5," * string(trunc(Int, SERVO_MIN + posDown * slope)))

  plotter.posUp = posUp
  plotter.posDown = posDown
end

function setspeed(plotter::Plotter, speedDown::Int, speedUp::Int)
  # Pen position units range from 0% to 100%, which correspond to
  # a typical timing range of 7500 - 25000 in units of 1/(12 MHz).
  # 1% corresponds to ~14.6 us, or 175 units of 1/(12 MHz).
  # Servo speed units (as set with setPenUpRate) are units of %/second,
  # referring to the percentages above.
  # The EBB takes speeds in units of 1/(12 MHz) steps
  # per 24 ms.  Scaling as above, 1% of range in 1 second
  # with SERVO_MAX = 27831 and SERVO_MIN = 9855
  # corresponds to 180 steps change in 1 s
  # That gives 0.180 steps/ms, or 4.5 steps / 24 ms.
  # Our input range (1-100%) corresponds to speeds up to
  # 100% range in 0.25 seconds, or 4 * 4.5 = 18 steps/24 ms.

  @assert 1 <= speedDown <= 100
  @assert 1 <= speedUp <= 100

  steps_per_second = SERVO_RANGE / SERVO_FASTEST_TIME
  # plotter unit is in 1/12 steps per 24ms
  cmd(plotter.port, "SC,11," * string(speedUp * 18))
  cmd(plotter.port, "SC,12," * string(speedDown * 18))

  plotter.speedUp = speedUp
  plotter.speedDown = speedDown
end

function penup(plotter::Plotter)
  move_distance = float(plotter.posUp - plotter.posDown)
  move_time = move_distance / (3 * plotter.speedUp)

  if plotter.penIsDown == false
    return
  end
  plotter.penIsDown = false
  cmd(plotter.port, "SP,1," * string(trunc(Int, move_time * 1000)))
  sleep(move_time - 0.01)
end

function pendown(plotter::Plotter)
  move_distance = float(plotter.posUp - plotter.posDown)
  move_time = move_distance / (3 * plotter.speedDown)

  if plotter.penIsDown == true
    return
  end
  plotter.penIsDown = true
  cmd(plotter.port, "SP,0," * string(trunc(Int, move_time * 1000)))
  sleep(move_time - 0.01)
end

println("connecting...")
plotter = Plotter("/dev/cu.usbmodem14101")
pendown(plotter)
penup(plotter)
pendown(plotter)
penup(plotter)
pendown(plotter)
penup(plotter)
