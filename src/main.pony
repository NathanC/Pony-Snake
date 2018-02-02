use "collections"
use "time"
use "random"

class val Point
  let x: ISize
  let y: ISize

  new val create(x': ISize, y': ISize) =>
    x = x'
    y = y'

  fun eq(that: box->Point): Bool =>
    (that.x == x) and (that.y == y)

class Notify is TimerNotify
  
  let _main: Main

  new iso create(main: Main) =>
    _main = main

  fun ref apply(timer: Timer, count: U64): Bool =>
    _main.step()
    true

class Handler is StdinNotify

    let _main: Main

    new iso create(main: Main) =>
        _main = main

    fun ref apply(
        data: Array[U8 val] iso
    ): None val =>

        try
          match ((consume data)(0)?) // we only expect 1 char from stdin
           | 'w' => _main.move(Up)
           | 'a' => _main.move(Left)
           | 's' => _main.move(Down)
           | 'd' => _main.move(Right)
           | 'q' => _main.quit()
          end
        end

actor Main

    let _env: Env
    var _accepting: Bool = true
    var _timers: Timers
    var _maybeDirection: (Direction| None) = None
    let _snake: List[Point] = List[Point]()
    var _berry: Point
    var _dice: Dice
    let _width: ISize = 10 // [1,x] 
    let _height: ISize = 10 // [1,y]
    let _speed_in_milliseconds: U64 = 100 // time between frames
    var _points: ISize = 0

    new create(env: Env) =>
        env.out.print("Starting the program.")
        env.input(Handler(this))
        _env = env

        let timers = Timers
        let timer = Timer(Notify(this), 0, 1_000_000 * _speed_in_milliseconds)
        timers(consume timer)

        _snake.unshift(Point(5,5))

        _timers = timers
        _dice = Dice(Rand)

        _berry = Point(_dice(1, _width.u64()).isize(), _dice(1, _height.u64()).isize())

    be quit() => _quit("Goodbye! Thanks for playing :)")

    fun ref _quit(message: String) =>
      _env.out.print(message)
      _env.input.dispose()
      _timers.dispose()
      _accepting = false

    fun _calculate_new_head(p: Point, d: Direction): Point => match d
        | Up => Point(p.x, if p.y == 1 then _height else p.y - 1 end)
        | Down => Point(p.x, if p.y == _height then 1 else p.y + 1 end)
        | Left => Point(if p.x == 1 then _width else p.x - 1 end, p.y)
        | Right => Point(if p.x == _width then 1 else p.x + 1 end, p.y)
      end

    fun ref _move_player_to(new_head: Point, grow: Bool = false) =>
        _snake.unshift(new_head)        
        if not grow then try _snake.pop()? end end


    // todo: As it stands, this allows for multiple moves being made between
    // frames, causing certain commands in quick-succession to be lost.
    // Current plan is either to push moves onto a queue, that is consumed at
    // a rate of 1 per frame.
    be move(d: Direction) if _accepting => 
      match (_maybeDirection, d) // don't allow going 180 degrees
      | (Down, Up) => None
      | (Left, Right) => None
      | (Up, Down) => None
      | (Right, Left) => None
      else
        _maybeDirection = d
      end
    be move(d: Direction) => None

    be step() =>  

        if(_accepting) then
          match _maybeDirection // todo: Find a cleaner way to use Options
            | let d: Direction => 

              try 
                let head = _snake.head()?()?
                let new_head = _calculate_new_head(head, d)

                if _snake.take(_snake.size() - 1).exists({(p: Point): Bool => p == new_head}) then
                  _quit("Whoops! Game over, please try again.")
                  return
                else 

                  let grow = 
                    if new_head == _berry then
                      _berry = Point(_dice(1, _width.u64()).isize(), _dice(1, _height.u64()).isize())
                      _points = _points + 1
                      true
                    else false
                    end

                  _move_player_to(new_head, grow)
                end
              end
          end
        end

        _render()

    fun _render() =>
        
        let buffer: Array[U8 val] iso = recover Array[U8 val]() end

        buffer.push('+')
        for x in Range[ISize](1, _width + 1) do 
            buffer.push('-')
            buffer.push('-')
        end
        buffer.push('-')
        buffer.push('+')
        buffer.push('\n')

        // todo: Improve performance
        // This is inefficent as it walks the whole snake upon every
        // grid location rendering, and I should use a different pattern.
        for y in Range[ISize](1, _height + 1) do
            buffer.push('|')
            buffer.push(' ')
            for x in Range[ISize](1, _width + 1) do 

                let cur = Point(x, y)

                if(cur == _berry) then
                  buffer.push('B')

                else
                  if _snake.exists({(p: Point): Bool => p == cur}) then 
                    buffer.push('O')
                  else buffer.push(' ')
                  end
                end

                buffer.push(' ')
            end
            buffer.push('|')
            buffer.push('\n')
        end    

        buffer.push('+')
        for x in Range[ISize](1, _width + 1) do 
            buffer.push('-')
            buffer.push('-')
        end
        buffer.push('-')
        buffer.push('+')
        // buffer.push('\n')

        let final: Array[U8 val] val = consume buffer
        
        _clear_screen() 
        _env.out.print("Use the wasd keys to move around! Or q to quit.")
        _env.out.print("Currently at " + _points.string() + " points.")
        _env.out.print(final)

    // only works on Linux.
    fun _clear_screen() =>
        _env.out.print("\ec\e[3J")

primitive Left
primitive Right
primitive Up
primitive Down

type Direction is (Left | Right | Up | Down)
