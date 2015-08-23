;;; nimblogger.el --- front end of nimblogger for Emacs -*- lexical-binding: t -*-

;; Copyright (C) 2015 by Yuta Yamada

;; Author: Yuta Yamada <cokesboy"at"gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "24.1"))
;; Keywords: Blogger, blog

;;; License:
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;; Commentary:
;; Configuration sample
;; work in progress
;;; Code:
(require 'cl-lib)
(require 'org)
(require 'ox-html)
(require 'let-alist)

(defvar nimblogger:blog-name nil)
(defvar nimblogger:multiple-blog-names nil
  "Set like below form if you want to use multiple blog name.
Use matched blog name that you specified directory when you push your
org file to Blogger.

For example:
'((\"blogname1\" . \"~/blogname1-directory\")
  (\"blogname2\" . \"~/blogname2-directory\"))")
(defvar nimblogger:template "#+TITLE:
#+OPTIONS: toc:nil \\n:nil num:nil
#+FILETAGS:
#+AUTHOR: "
  "Template for `nimblogger:insert-template'")

(defvar nimblogger:command "nimblogger")

(defun nimblogger:insert-template ()
  "Insert blog template"
  (interactive)
  (insert nimblogger:template))

(defun nimblogger-get-options ()
  (let ((options (org-export--get-inbuffer-options)))
    (mapcar (lambda (sym)
              (let ((val (plist-get options sym)))
                (cons (if (eq :filetags sym)
                          :labels
                        sym)
                      (cl-typecase val
                        (string val)
                        (list (car val))))))
            '(:author :filetags :title))))

(defun nimblogger:export-html ()
  (interactive)
  (org-html-export-to-html nil nil nil t))

(defun nimblogger:get-blog-name ()
  ""
  (if nimblogger:multiple-blog-names
      (cl-loop for (blogname . directory) in nimblogger:multiple-blog-names
               if (string-match (concat "^" (file-truename directory))
                                buffer-file-name)
               do (cl-return blogname))
    nimblogger:blog-name))

(defun nimblogger:make-command ()
  (let-alist (nimblogger-get-options)
    (let* ((title (format "--title:\"%s\""
                          (if (equal .title "")
                              (read-string "title here: ")
                            .:title)))
           (blogname (format "--blogname:%s"
                             (nimblogger:get-blog-name)))
           (exported-file (format "%s%s.html"
                                  (file-name-directory buffer-file-name)
                                  (file-name-base)))
           (filetags ; optional configuration
               (when .:labels (format "--labels:\"%s\"" .:labels))))
      (when (and (nimblogger:export-html) (file-exists-p exported-file))
        (let ((args
               (delq nil `(,title ,blogname
                           ,(format "--file:%s" exported-file) ,filetags))))
          (substring-no-properties
           (format "%s post %s" nimblogger:command (mapconcat 'identity args " "))))))))

;;;###autoload
(defun nimblogger:post-article ()
  "Post article."
  (interactive)
  (async-shell-command
   (nimblogger:make-command) (get-buffer-create "*nimblogger*")))

;; nimblogger post --blogname:xxx --file:xxx --labels:"foo, bar"
(provide 'nimblogger)

;; Local Variables:
;; coding: utf-8
;; mode: emacs-lisp
;; End:

;;; nimblogger.el ends here
