- TODOs
 - [ ] Write README
 - [ ] Write some docs
 - [x] nixpkgs
 - [ ] templates
 - [ ] put all nixos / nix-darwin modules into stories
 - [ ] nix-story-deploy-rs
 - [ ] nix-story-treefmt
 - [ ] np cli for managing inputs
    - Auto-set follows
    - Apply templates

basement = this flake, implements the prefab API, as well as flake-modules and nixpkgs handling
plumbing-* = Shared infrastructure for stories. Does not output anything to the flake. Usually provides some data in the `prefab.<name>` config attribute.
story-* = Adds functionality to the flake.
