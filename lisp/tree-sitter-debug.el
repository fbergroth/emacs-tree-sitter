;;; tree-sitter-debug.el --- Debug tools for tree-sitter -*- lexical-binding: t; coding: utf-8 -*-

;; Copyright (C) 2019  Tuấn-Anh Nguyễn
;;
;; Author: Tuấn-Anh Nguyễn <ubolonton@gmail.com>

;;; Commentary:

;; This file contains debug utilities for tree-sitter.
;;
;; (tree-sitter-debug-mode)

;;; Code:

(require 'tree-sitter)

(defvar-local tree-sitter-debug--tree-buffer nil
  "Buffer used to display the syntax tree of this buffer.")

(defun tree-sitter-debug--display-node (node depth)
  "Display NODE that appears at the given DEPTH in the syntax tree."
  (insert (format "%s%s: \n" (make-string (* 2 depth) ?\ ) (ts-node-type node)))
  (ts-mapc-children (lambda (c)
                      (when (ts-node-named-p c)
                        (tree-sitter-debug--display-node c (1+ depth))))
                    node))

(defun tree-sitter-debug--display-tree (_old-tree)
  "Display the current `tree-sitter-tree'."
  ;; TODO: Re-render only affected nodes.
  (when-let ((tree tree-sitter-tree))
    (with-current-buffer tree-sitter-debug--tree-buffer
      (erase-buffer)
      (tree-sitter-debug--display-node (ts-root-node tree) 0))))

(defun tree-sitter-debug--setup ()
  "Set up syntax tree debugging in the current buffer."
  (unless (buffer-live-p tree-sitter-debug--tree-buffer)
    (setq tree-sitter-debug--tree-buffer
          (get-buffer-create (format "tree-sitter-tree: %s" (buffer-name)))))
  (add-hook 'tree-sitter-after-change-functions #'tree-sitter-debug--display-tree nil :local)
  (add-hook 'kill-buffer-hook #'tree-sitter-debug--teardown nil :local)
  (display-buffer tree-sitter-debug--tree-buffer)
  (tree-sitter-debug--display-tree nil))

(defun tree-sitter-debug--teardown ()
  "Tear down syntax tree debugging in the current buffer."
  (remove-hook 'tree-sitter-after-change-functions #'tree-sitter-debug--display-tree :local)
  (when (buffer-live-p tree-sitter-debug--tree-buffer)
     (kill-buffer tree-sitter-debug--tree-buffer)
     (setq tree-sitter-debug--tree-buffer nil)))

;;;###autoload
(define-minor-mode tree-sitter-debug-mode
  "Toggle syntax tree debugging for the current buffer.
This mode displays the syntax tree in another buffer, and keeps it up-to-date."
  :init-value nil
  :group 'tree-sitter
  (tree-sitter--handle-dependent tree-sitter-debug-mode
    #'tree-sitter-debug--setup
    #'tree-sitter-debug--teardown))

;;;###autoload
(defun tree-sitter-debug-query (patterns &optional matches tag-assigner)
  "Execute query PATTERNS against the current syntax tree and return captures.

If the optional arg MATCHES is non-nil, matches (from `ts-query-matches') are
returned instead of captures (from `ts-query-captures').

If the optional arg TAG-ASSIGNER is non-nil, it is passed to `ts-make-query' to
assign custom tags to capture names.

This function is primarily useful for debugging purpose. Other packages should
build queries and cursors once, then reuse them."
  (let* ((query (ts-make-query tree-sitter-language patterns tag-assigner))
         (root-node (ts-root-node tree-sitter-tree)))
    (ts--without-restriction
      (if matches
          (ts-query-matches query root-node #'ts--buffer-substring-no-properties)
        (ts-query-captures query root-node #'ts--buffer-substring-no-properties)))))

;;; TODO: Kill tree-buffer when `tree-sitter' minor mode is turned off.

(provide 'tree-sitter-debug)
;;; tree-sitter-debug.el ends here
