# Simple Snake Game in Pony

![Gameplay recording](https://i.imgur.com/mTPy7xt.gif)

Recently I stumbled across the language [Pony](https://www.ponylang.org/), and it caught my interest. According to the homepage, 

> Pony is an open-source, object-oriented, actor-model, capabilities-secure, high-performance programming language.

Actors as a first class citizen intrigued me, as well as the capability model that pony uses (to prevent data race conditions).

Anyhow, this is a simple Snake game that I wrote while tinkering around with the language. To run it, make sure `ponyc` is on your path, and run:

```bash
cd src
ponyc . -b snake
./snake
```
