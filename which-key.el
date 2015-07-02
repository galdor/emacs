;;; which-key.el

;; Copyright (C) 2015 Justin Burkett

;; Author: Justin Burkett <justin@burkett.cc>
;; URL: http://github.com/justbur/which-key/
;; Version: 0.1
;; Keywords:
;; Package-Requires: ((s "1.9.0"))

;;; Commentary:
;;
;;  Rewrite of guide-key-mode.
;;

;;; Code:

(defvar which-key-timer nil
  "Internal variable to hold reference to timer.")
(defvar which-key-idle-delay 0.5
  "Delay (in seconds) for which-key buffer to popup.")
(defvar which-key-max-description-length 30
  "Truncate the description of keys to this length (adds
  \"..\")")
(defvar which-key-key-replacement-alist
  '((">". "") ("<" . "") ("left" ."←") ("right" . "→"))
  "The strings in the car of each cons cell are replaced with the
  strings in the cdr for each key.")
(defvar which-key-description-replacement-alist nil
  "See `which-key-key-replacement-alist'. This is a list of cons
  cells for replacing the description of keys (usually the name
  of the corresponding function).")

(defvar which-key-buffer nil
  "Internal variable to hold reference to which-key buffer.")
(defvar which-key-buffer-name "*which-key*"
  "Name of which-key buffer.")
(defvar which-key-buffer-position 'right
  "Position of which-key buffer")
(defvar which-key-buffer-width 80
  "Width of which-key buffer (hardcoded for now).")

(defvar which-key-setup-p nil
  "Non-nil if which-key buffer has been setup")

(define-minor-mode which-key-mode
  "Toggle which-key-mode."
  :global t
  :lighter " WK"
  :require 'popwin
  :require 's
  (funcall (if which-key-mode
               (progn
                 (unless which-key-setup-p (which-key/setup))
                 'which-key/turn-on-timer)
             'which-key/turn-off-timer)))

(defsubst which-key/truncate-description (desc)
  "Truncate key description to `which-key-max-description-length'."
  (if (> (length desc) which-key-max-description-length)
      (concat (substring desc 0 which-key-max-description-length) "..")
    desc))

(defun which-key/format-matches (key-desc-cons max-len-key max-len-desc)
  "Turn `key-desc-cons' into formatted strings (including text
properties), and pad with spaces so that all are a uniform
length."
  (let* ((key (car key-desc-cons))
         (desc (cdr key-desc-cons))
         (group (string-match-p "^group:" desc))
         (prefix (string-match-p "^Prefix" desc))
         (desc-face (if (or prefix group)
                        'font-lock-keyword-face 'font-lock-function-name-face))
         (tmp-desc (which-key/truncate-description (if group (substring desc 6) desc)))
         (key-padding (s-repeat (- max-len-key (length key)) " "))
         (padded-desc (s-pad-right max-len-desc " " tmp-desc)))
    (format (concat (propertize "[" 'face 'font-lock-comment-face) "%s"
                    (propertize "]%s" 'face 'font-lock-comment-face)
                    (propertize " %s" 'face desc-face))
            key key-padding padded-desc)))

(defun which-key/replace-strings-from-alist (replacements)
  "Find and replace text in buffer according to REPLACEMENTS,
which is an alist where the car of each element is the text to
replace and the cdr is the replacement text. "
  (dolist (rep replacements)
    (save-excursion
      (while (search-forward (car rep) nil t)
        (replace-match (cdr rep) nil t)))))

(defun which-key/insert-keys (formatted-strings)
  "Insert strings into buffer breaking after `which-key-buffer-width'."
  (let ((char-count 0))
    (insert (mapconcat
             (lambda (str)
               (let* ((str-len (length (substring-no-properties str)))
                      (new-count (+ char-count str-len)))
                 (if (> new-count which-key-buffer-width)
                     (progn (setq char-count str-len)
                            (concat "\n" str))
                   (setq char-count new-count)
                   str))) formatted-strings ""))))

(defun which-key/update-buffer-and-show ()
  "Fill which-key-buffer with key descriptions and reformat. Finally, show the buffer."
  (let ((key (this-single-command-keys)))
    (when (> (length key) 0)
      (let ((buf (current-buffer))
            (key-str-qt (regexp-quote (key-description key)))
            unformatted formatted)
        (with-current-buffer (get-buffer which-key-buffer)
          (erase-buffer)
          (describe-buffer-bindings buf key)
          (goto-char (point-max))
          (let ((max-len-key 0) (max-len-desc 0) key-match desc-match)
            (while (re-search-backward
                    (format "^%s \\([^ \t]+\\)[ \t]+\\(\\(?:[^ \t\n]+ ?\\)+\\)$" key-str-qt)
                    nil t)
              (setq key-match (s-replace-all which-key-key-replacement-alist (match-string 1))
                    desc-match (match-string 2)
                    max-len-key (max max-len-key (length key-match))
                    max-len-desc (max max-len-desc (length desc-match)))
              (cl-pushnew (cons key-match desc-match) unformatted
                          :test (lambda (x y) (string-equal (car x) (car y)))))
            (setq max-len-desc (if (> max-len-desc which-key-max-description-length)
                                   (+ 2 which-key-max-description-length)
                                 max-len-desc))
            (setq formatted (mapcar (lambda (str)
                                      (which-key/format-matches str max-len-key max-len-desc))
                                    unformatted)))
          (erase-buffer)
          (which-key/insert-keys formatted)
          (goto-char (point-min))
          (which-key/replace-strings-from-alist which-key-description-replacement-alist)))
      (display-buffer which-key-buffer))))

(defun which-key/setup ()
  "Create buffer for which-key and add buffer to `popwin:special-display-config'"
  (setq which-key-buffer (get-buffer-create which-key-buffer-name))
  (add-to-list 'popwin:special-display-config
               `(,which-key-buffer-name
                 :width ,which-key-buffer-width
                 :noselect t
                 :position ,which-key-buffer-position))
  (setq which-key-setup-p t))

(defun which-key/turn-on-timer ()
  "Activate idle timer."
  (setq which-key-timer
        (run-with-idle-timer which-key-idle-delay t 'which-key/update-buffer-and-show)))

(defun which-key/turn-off-timer ()
  "Deactivate idle timer."
  (cancel-timer which-key-timer))

