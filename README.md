# Cabbage

[![Build Status](https://semaphoreci.com/api/v1/cabbage-ex/cabbage/branches/master/shields_badge.svg)](https://semaphoreci.com/cabbage-ex/cabbage)
[![Hex.pm](https://img.shields.io/hexpm/v/cabbage.svg)]()

<img src="https://www.organicfacts.net/wp-content/uploads/2013/12/redcabbage.jpg" width="240px" height="180px"></img>
##### (Looking contribution for a better icon!)

A simple addon on top of [ExUnit](https://hexdocs.pm/ex_unit/ExUnit.html) which provides compile time translation of `.feature` files to exunit tests. Big thanks to [@meadsteve](https://github.com/meadsteve) and the [White Bread](https://github.com/meadsteve/white-bread) project for a huge head start on this project.

## Docs

- [Usage](https://hexdocs.pm/cabbage/Cabbage.Case.html)
- [Config](https://hexdocs.pm/cabbage/Cabbage.Config.html)

## Installation

[Available in Hex](https://hex.pm/packages/cabbage), the package can be installed as:

  1. Add `cabbage` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:cabbage, "~> 0.4.0"}]
end
```

# Roadmap

- [x] Scenarios
- [x] Scenario Outlines
- [x] ExUnit Case Templates
- [x] Data tables
- [x] Executing specific tests
- [x] Tags implementation
- [ ] Background steps
- [ ] Integration Helpers for Wallaby (separate project?)
- [ ] Integration Helpers for Hound (separate project?)
