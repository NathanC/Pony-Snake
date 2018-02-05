use "collections"
use "time"
use "random"

class val Segment
  let pos: Point
  let corner: Bool 
  let direction: Direction

  new val create(pos': Point, direction': Direction, corner': Bool = false) =>
      pos = pos'
      corner = corner'
      direction = direction'

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
    var _move_queue: List[Direction] = List[Direction]()
    var _current_direction: (Direction | None) = None
    let _body: List[Segment] = List[Segment]()
    var _berry: Point
    var _dice: Dice
    let _width: ISize = 10 // [1,x] 
    let _height: ISize = 10 // [1,y]
    let _speed_in_milliseconds: U64 = 100 // time between frames
    var _points: ISize = 0

    // head ---> body segment list ---> tail
    var _head: Segment
    var _tail: Segment

    new create(env: Env) =>
        env.out.print("Starting the program.")
        env.input(Handler(this))
        _env = env

        let timers = Timers
        let timer = Timer(Notify(this), 0, 1_000_000 * _speed_in_milliseconds)
        timers(consume timer)

        _tail = Segment(Point(1,1), Down)
        _head = Segment(Point(1,2), Down)

        _timers = timers
        (let seconds, let nanoseconds) = Time.now() // To seed PRNG
        _dice = Dice(XorOshiro128Plus(seconds.u64(), nanoseconds.u64()))

        _berry = Point(_dice(1, _width.u64()).isize(), _dice(1, _height.u64()).isize())

    be quit() => _quit("Goodbye! Thanks for playing :)")

    fun ref _quit(message: String) =>
      _env.out.print(message)
      _env.input.dispose()
      _timers.dispose()
      _accepting = false

    fun _calculate_new_head(p: Point, d: Direction): Segment => 

      let new_pos = match d
        | Up => Point(p.x, if p.y == 1 then _height else p.y - 1 end)
        | Down => Point(p.x, if p.y == _height then 1 else p.y + 1 end)
        | Left => Point(if p.x == 1 then _width else p.x - 1 end, p.y)
        | Right => Point(if p.x == _width then 1 else p.x + 1 end, p.y)
      end

      Segment(new_pos, d)

    be move(d: Direction) if _accepting => 

      let allowed_move = {
        (d1: Direction, d2: Direction): Bool => 
            match (d1, d2) // don't allow going 180 degrees
              | (Down, Up) => false
              | (Left, Right) => false
              | (Up, Down) => false
              | (Right, Left) => false
            else
              true
            end
        }

      if _move_queue.size() < 3 then

        try
          let head = _move_queue.head()?()? // <-- weird notation, amirite?

          if allowed_move(head, d) then
            _move_queue.unshift(d)
          end

        else

          match _current_direction
            | let curr: Direction => 
              if allowed_move(curr, d) then
              _move_queue.unshift(d)
              end
          else
            _move_queue.unshift(d)
          end

        end  

      end // reject moves if the queue already contains 3 or more moves

    be move(d: Direction) => None

    be step() =>  

        if(_accepting) then

          try
            _current_direction = _move_queue.pop()? //pop if it exists
          end 

          match _current_direction
            | let d: Direction => 
              
              let new_head = _calculate_new_head(_head.pos, d)
              let old_head = _head
              _head = new_head

              // turn the old head into a body segment, inside the list  
              _body.unshift(Segment(old_head.pos, old_head.direction, not (old_head.direction is new_head.direction)))

              if _body.exists({(s: Segment): Bool => s.pos == new_head.pos}) then
                _quit("Whoops! Game over, please try again.")
                return
              elseif new_head.pos == _berry then
                _berry = Point(_dice(1, _width.u64()).isize(), _dice(1, _height.u64()).isize())
                _points = _points + 1
                // no need to change the old tail
              else
                // Standard flow-- moving into an empty space.
                try
                  _tail = _body.pop()? // overwrite the tail with the last body segment
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

        for y in Range[ISize](1, _height + 1) do
            buffer.push('|')
            buffer.push(' ')
            for x in Range[ISize](1, _width + 1) do 

                buffer.push(' ') // background character
                buffer.push(' ') // spacing
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

        // now that the backrgound world has been painted, we can
        // paint over with entities in whatever order we wish. 

        let calculate_index = {(p: Point): USize => USize.from[ISize]((((_width * 2) + 4) * p.y) + (p.x * 2))}
          
        try 

          buffer.update(calculate_index(_head.pos), '#')?

          for segment_node in _body.nodes() do
            let segment = segment_node()?

            let char: U8 = 
              if segment.corner == true then
                '+'
              else match segment.direction
                  | Down => '|'
                  | Up => '|'
                  | Left => '-'
                  | Right => '-'
                end

              end

            buffer.update(calculate_index(segment.pos), char)?
          end

          buffer.update(calculate_index(_tail.pos), '*')?

          buffer.update(calculate_index(_berry), 'O')?
        end
    
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
