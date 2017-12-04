open Lib
open Lib.Metatags
open OUnit
open Base

(** Test helper funcs *)

let to_meta_html name content = ("<meta name=\"" ^ name ^ "\" content=\"" ^ content ^ "\" />")

(** Create a <meta> html node with given name and content *)
let meta_node name content = 
  let node = to_meta_html name content
             |> Soup.parse
             |> Soup.select_one "meta"
             |> Option.map ~f:(fun a -> a) in
  Option.value_exn node

(** Create a list of <meta> html nodes from a list of name, content tuples *)
let meta_nodes pairs =
  pairs 
  |> List.map ~f:(fun (n, c) -> to_meta_html n c)
  |> List.reduce_exn ~f:(^)
  |> Soup.parse
  |> Soup.tags "meta"

let or_empty opt = opt |> Option.value ~default:""

let suite = "socialpeek" >::: [
    "Metadata.name_attr" >:: (fun _ ->
        let node_name = meta_node "yada" "foo" in
        let node_empty = meta_node "" "bar" in
        assert_equal (name_attr node_name) "yada" ~msg:"with name";
        assert_equal (name_attr node_empty) "" ~msg:"with no name"
      );

    "Metadata.content_attr" >:: (fun _ ->
        let node_content = meta_node "yada" "foo" in
        let node_empty = meta_node "yada" "" in
        assert_equal (content_attr node_content) "foo" ~msg:"with content";
        assert_equal (content_attr node_empty) "" ~msg:"with no content"
      );

    "Metadata.pair_of_node_with_prefix" >:: (fun _ ->
        let prefixed_node = meta_node "foo:bar" "baz" in
        let not_prefixed = meta_node "foo" "baz" in

        let r1 = pair_of_node_with_prefix "foo" prefixed_node in
        let r2 = pair_of_node_with_prefix "foo" not_prefixed in
        assert_bool "prefixed should return something" (Option.is_some r1);
        assert_equal (Option.value_exn r1) ("foo:bar", "baz") ~msg:"should return name-content pair";
        assert_bool "not prefixed should return nothing" (Option.is_none r2)
      );

    "Metadata.tags_of_group" >:: (fun _ ->
        let nodes = meta_nodes [
            ("not_prefixed", "bar");
            ("not_prefixed", "foo");
            ("also_not_prefixed", "qux");
            ("prefix:yada", "foo");
            ("prefix:yada", "bar");
            ("prefix:foo", "baz")
          ] in
        let group = tags_of_group "prefix" nodes in
        assert_equal (Map.length group) 2 ~msg:"should contain only prefixed nodes";
        assert_equal (Map.find_exn group "prefix:yada") ["foo"; "bar"];
        assert_equal (Map.find_exn group "prefix:foo") ["baz"]
      );

    "Metadata.group" >:: (fun _ ->
        let nodes = meta_nodes [
            ("twitter:card", "player");
            ("twitter:card", "summary");
            ("og:title", "foo");
            ("og:description", "bar");
            ("something", "bux");
            ("yada:yada", "bax")
          ] in
        let {twitter; opengraph} = group nodes in
        assert_equal (Map.length twitter) 1 ~msg:"should contain 1 twitter tag";
        assert_equal (Map.find_exn twitter "twitter:card") ["player"; "summary"];
        assert_equal (Map.length opengraph) 2 ~msg:"should contain 2 opengraph tags";
        assert_equal (Map.find_exn opengraph "og:title") ["foo"] ~msg:"og:title should be foo";
        assert_equal (Map.find_exn opengraph "og:description") ["bar"] ~msg:"og:description should be bar"
      );

    "Lib.from_html" >:: (fun _ ->
        let html = "<!DOCTYPE html><html><head>" ^
                   "<meta name=\"twitter:card\" content=\"foo\" />" ^
                   "<meta name=\"og:title\" content=\"bar\" />" ^
                   "</head></html>"
        in
        let {twitter; opengraph} = from_html html in
        assert_equal (Map.length twitter) 1 ~msg:"should contain 1 twitter tag";
        assert_equal (Map.find_exn twitter "twitter:card") ["foo"] ~msg:"twitter:card should be foo";
        assert_equal (Map.length opengraph) 1 ~msg:"should contain 1 opengraph tag";
        assert_equal (Map.find_exn opengraph "og:title") ["bar"] ~msg:"og:title should be bar";
      );

    "Twitter.get_card with only opengraph data" >:: (fun _ ->
        let groups = meta_nodes [
            ("og:title", "title");
            ("og:description", "description");
            ("og:image", "image")
          ] |> group in
        let card = Twitter.get_card groups in
        match card with
        | Twitter.Summary data ->
          assert_equal data.title "title";
          assert_equal data.description "description";
          assert_equal (data.image |> Option.value ~default:"") "image";
        | _ -> assert_failure "card should be summary"
      );

    "Twitter.get_card with type set in og:type" >:: (fun _ ->
        let groups = meta_nodes [
            ("og:type", "summary_large_image");
            ("og:title", "title");
            ("og:description", "description");
            ("og:image", "image")
          ] |> group in
        let card = Twitter.get_card groups in
        match card with
        | Twitter.Summary_large_image data ->
          assert_equal data.title "title";
          assert_equal data.description "description";
          assert_equal (or_empty data.image) "image";
        | _ -> assert_failure "card should be summary_large_image"
      );

    "Twitter.get_card summary with all fields" >:: (fun _ ->
        let groups = meta_nodes [
            ("twitter:card", "summary");
            ("twitter:title", "title");
            ("og:title", "title2");
            ("twitter:description", "description");
            ("og:description", "description2");
            ("twitter:image", "image");
            ("og:image", "image2");
            ("twitter:image:alt", "image_alt");
            ("twitter:site", "site");
            ("twitter:site:id", "site_id");
            ("twitter:creator:id", "creator_id");
          ] |> group in
        let card = Twitter.get_card groups in
        match card with
        | Twitter.Summary data ->
          assert_equal data.title "title" ~msg:"title";
          assert_equal data.description "description" ~msg:"description";
          assert_equal (or_empty data.image) "image" ~msg:"image";
          assert_equal data.image_alt "image_alt" ~msg:"image_alt";
          assert_equal (or_empty data.site) "site" ~msg:"site";
          assert_equal (or_empty data.site_id) "site_id" ~msg:"site_id";
          assert_equal (or_empty data.creator_id) "creator_id" ~msg:"creator_id";
        | _ -> assert_failure "card should be summary"
      );

    "Twitter.get_card summary_large_image with all fields" >:: (fun _ ->
        let groups = meta_nodes [
            ("twitter:card", "summary_large_image");
            ("twitter:title", "title");
            ("og:title", "title2");
            ("twitter:description", "description");
            ("og:description", "description2");
            ("twitter:image", "image");
            ("og:image", "image2");
            ("twitter:image:alt", "image_alt");
            ("twitter:site", "site");
            ("twitter:site:id", "site_id");
            ("twitter:creator", "creator");
            ("twitter:creator:id", "creator_id");
          ] |> group in
        let card = Twitter.get_card groups in
        match card with
        | Twitter.Summary_large_image data ->
          assert_equal data.title "title" ~msg:"title";
          assert_equal data.description "description" ~msg:"description";
          assert_equal (or_empty data.image) "image" ~msg:"image";
          assert_equal data.image_alt "image_alt" ~msg:"image_alt";
          assert_equal (or_empty data.site) "site" ~msg:"site";
          assert_equal (or_empty data.site_id) "site_id" ~msg:"site_id";
          assert_equal (or_empty data.creator) "creator" ~msg:"creator";
          assert_equal (or_empty data.creator_id) "creator_id" ~msg:"creator_id";
        | _ -> assert_failure "card should be summary_large_image"
      );

    "Twitter.get_card app with all fields" >:: (fun _ ->
        let groups = meta_nodes [
            ("twitter:card", "app");
            ("twitter:site", "site");

            ("twitter:app:name:iphone", "iphone_name");
            ("twitter:app:url:iphone", "iphone_url");
            ("twitter:app:id:iphone", "iphone_id");

            ("twitter:app:name:ipad", "ipad_name");
            ("twitter:app:url:ipad", "ipad_url");
            ("twitter:app:id:ipad", "ipad_id");

            ("twitter:app:name:googleplay", "gp_name");
            ("twitter:app:url:googleplay", "gp_url");
            ("twitter:app:id:googleplay", "gp_id");
          ] |> group in
        let card = Twitter.get_card groups in
        match card with
        | Twitter.App data ->
          assert_equal data.site "site" ~msg:"site";
          assert_equal data.iphone.name "iphone_name" ~msg:"iphone:name";
          assert_equal data.iphone.id "iphone_id" ~msg:"iphone:id";
          assert_equal data.iphone.url "iphone_url" ~msg:"iphone:url";
          assert_equal data.ipad.name "ipad_name" ~msg:"ipad:name";
          assert_equal data.ipad.id "ipad_id" ~msg:"ipad:id";
          assert_equal data.ipad.url "ipad_url" ~msg:"ipad:url";
          assert_equal data.google_play.name "gp_name" ~msg:"google_play:name";
          assert_equal data.google_play.id "gp_id" ~msg:"google_play:id";
          assert_equal data.google_play.url "gp_url" ~msg:"google_play:url";
        | _ -> assert_failure "card should be app"
      );

    "Twitter.get_card player with all fields" >:: (fun _ ->
        let groups = meta_nodes [
            ("twitter:card", "player");
            ("twitter:title", "title");
            ("og:title", "title2");
            ("twitter:description", "description");
            ("og:description", "description2");
            ("twitter:image", "image");
            ("og:image", "image2");
            ("twitter:image:alt", "image_alt");
            ("twitter:site", "site");
            ("twitter:site:id", "site_id");
            ("twitter:player", "player");
            ("twitter:player:width", "1");
            ("twitter:player:height", "2");
            ("twitter:player:stream", "stream");
          ] |> group in
        let card = Twitter.get_card groups in
        match card with
        | Twitter.Player data ->
          assert_equal data.title "title" ~msg:"title";
          assert_equal data.description "description" ~msg:"description";
          assert_equal (or_empty data.image) "image" ~msg:"image";
          assert_equal data.image_alt "image_alt" ~msg:"image_alt";
          assert_equal (or_empty data.site) "site" ~msg:"site";
          assert_equal (or_empty data.site_id) "site_id" ~msg:"site_id";
          assert_equal (or_empty data.player) "player" ~msg:"player";
          assert_equal (or_empty data.stream) "stream" ~msg:"stream";
          assert_equal data.width 1 ~msg:"width";
          assert_equal data.height 2 ~msg:"height";
        | _ -> assert_failure "card should be player"
      );

    "Twitter.get_card player with all invalid height and width" >:: (fun _ ->
        let groups = meta_nodes [
            ("twitter:card", "player");
            ("twitter:player:width", "hello");
            ("twitter:player:height", "world");
          ] |> group in
        let card = Twitter.get_card groups in
        match card with
        | Twitter.Player data ->
          assert_equal data.width 0 ~msg:"width";
          assert_equal data.height 0 ~msg:"height";
        | _ -> assert_failure "card should be player"
      );
  ]

let _ = run_test_tt_main suite