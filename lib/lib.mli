open Base
open Lwt

module Twitter = Twitter
module Metatags = Metatags

type error = Error_code of int | Missing_location_header

val from_html : string -> Metatags.grouped_metatags

val from_url : string -> (Metatags.grouped_metatags, error) Result.t