# ocaml-socialpeek

OCaml library to extract social information such as Twitter cards or OpenGraph data from webpages and HTML.

## Install

It's not published on opam (yet), so to install this you need to clone the repository and pin it.

```bash
git clone https://github.com/erizocosmico/ocaml-socialpeek.git
opam pin add . -y
```

## Usage

### Get twitter card

```ocaml
open Socialpeek

let () =
  (** you can use `from_html` instead if you already have the HTML *)
  let twitter_card = from_url "http://something.cool" |> Twitter.get_card in
  match twitter_card with
  | Twitter.Summary data -> (** Do something with data *)
  | Twitter.Summary_large_image data -> (** Do something with data *)
  | Twitter.App data -> (** Do something with data *)
  | Twitter.Player data -> (** Do something with data *)
```

Twitter cards can have 4 different shapes: `summary`, `summary_large_image`, `app` or `player` (more info about [twitter cards](https://developer.twitter.com/en/docs/tweets/optimize-with-cards/overview/markup)).
So the result of `Twitter.get_card` is a variant type that holds only the data a certain type of card can have.

### Get Opengraph data

```ocaml
open Socialpeek

let () =
  (** you can use `from_html` instead if you already have the HTML *)
  let og_data = from_url "http://something.cool" |> Opengraph.get_data in
  (** do something with the data *)
```

### Get twitter and opengraph data

```ocaml
open Socialpeek

let () =
  (** you can use `from_html` instead if you already have the HTML *)
  let tags = from_url "http://something.cool" in
  let og_data = Opengraph.get_data tags in
  let twitter_card = Twitter.get_card tags in
  (** do something with the data *)
```

## License

MIT, see [LICENSE](/LICENSE)
