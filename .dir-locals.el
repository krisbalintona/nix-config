;;; Directory Local Variables            -*- no-byte-compile: t -*-
;;; For more information see (info "(emacs) Directory Variables")

((nil . ((compile-multi-config . (((file-exists-p "justfile")
                                   ("just:list" . "just --list")
                                   ("just:home-manager" . "just home-manager")
                                   ("just:nixos" . "just nixos")
                                   ("just:update" . "just update")))))))
