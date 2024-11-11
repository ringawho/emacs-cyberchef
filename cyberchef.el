;;; cyberchef.el --- emacs cyberchef  -*- lexical-binding: t -*-

;; Copyright (C) 2018, Andy Stewart, all rights reserved.

;; Author:          ringawho <ringawho@sina.com>
;; Maintainer:      ringawho <ringawho@sina.com>
;; Created:         Aug 24, 2024
;; Keywords:
;; Package-Version: 0.1
;; Package-Requires: ((websocket "1.15") (json "1.5"))
;; Homepage:  https://github.com/ringawho/emacs-cyberchef

;; This file is not part of Emacs

;;; License

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Encrypt or decrypt text in Emacs using CyberChef.
;;

;;; Usage:

;; 1. M-x `cyberchef-start' or put (cyberchef-start) in your init file.
;; 2. M-x `cyberchef', encrypt/decrypt region or `symbol-at-point'
;;    according to your configuration file.

;;; Code:

(require 'websocket)
(require 'json)

(defgroup cyberchef nil
  "Cyberchef group."
  :group 'tools)

(defcustom cyberchef-proc-and-buf-name "*cyberchef*"
  "Name of Holo-Layer buffer."
  :type 'string)

(defcustom cyberchef-output-buf-name "*cyberchef-output*"
  "Name of Holo-Layer buffer."
  :type 'string)

(defcustom cyberchef-config-file (expand-file-name "cyberchef.json" user-emacs-directory)
  "The cyberchef config file."
  :type 'directory
  :group 'cyberchef)

(defvar cyberchef-js-file (expand-file-name "cyberchef.mjs"
                                            (if load-file-name
                                                (file-name-directory load-file-name)
                                              default-directory)))
(defvar cyberchef-js-process nil)
(defvar cyberchef-ws-server nil)
(defvar cyberchef-ws-conn nil)
(defvar cyberchef-exec-timer nil)

(defun cyberchef--ws-on-message (_ws frame)
  (let* ((parsed (json-read-from-string (websocket-frame-text frame)))
         (status (alist-get 'status parsed))
         (msg (alist-get 'message parsed))
         (postproc (alist-get 'postproc parsed))
         buf)
    (when cyberchef-exec-timer
      (cancel-timer cyberchef-exec-timer)
      (setq cyberchef-exec-timer nil)
      (message "[Cyberchef] Done."))
    (if (< status 0)
        (message msg)
      (when postproc
        (eval (car (read-from-string postproc))
              (list (cons 'res msg))))
      (setq buf (get-buffer-create cyberchef-output-buf-name))
      (with-current-buffer buf
        (erase-buffer)
        (insert msg)
        (switch-to-buffer-other-window buf)))))

(defun cyberchef--ws-on-open (ws)
  (set-process-query-on-exit-flag (websocket-conn ws) nil)
  (setq cyberchef-ws-conn ws))

(defun cyberchef--ws-on-close (_ws)
  (setq cyberchef-ws-conn nil))

;;;###autoload
(defun cyberchef-start ()
  (interactive)
  (when (or cyberchef-js-process cyberchef-ws-server cyberchef-ws-conn)
    (error "[Cyberchef] Process is already running, or you can execute `cyberchef-restart'"))
  (setq cyberchef-ws-server
        (websocket-server t :host 'local
                          :on-open #'cyberchef--ws-on-open
                          :on-message #'cyberchef--ws-on-message
                          :on-close #'cyberchef--ws-on-close))
  (let ((port (cadr (process-contact cyberchef-ws-server))))
    (setq cyberchef-js-process
          (start-process cyberchef-proc-and-buf-name
                         cyberchef-proc-and-buf-name
                         "node"
                         cyberchef-js-file
                         (number-to-string port)))
    (set-process-query-on-exit-flag cyberchef-js-process nil)))

;;;###autoload
(defun cyberchef-close (&optional restart)
  (interactive)
  (when cyberchef-js-process
    (set-process-buffer cyberchef-js-process nil)
    (ignore-errors
      (kill-process cyberchef-js-process))
    (setq cyberchef-js-process nil)
    (if restart
        (with-current-buffer cyberchef-proc-and-buf-name
          (erase-buffer))
      (kill-buffer cyberchef-proc-and-buf-name)
      (message "[Cyberchef] Process terminated.")))
  (when cyberchef-ws-server
    (ignore-errors
      (websocket-server-close cyberchef-ws-server))
    (setq cyberchef-ws-server nil)))

(add-hook 'kill-emacs-hook #'cyberchef-close)

;;;###autoload
(defun cyberchef-restart ()
  (interactive)
  (cyberchef-close t)
  (cyberchef-start)
  (message "[Cyberchef] Process restarted."))

;;;###autoload
(defun cyberchef ()
  (interactive)
  (cond
   ((not (file-exists-p cyberchef-config-file))
    (message (format "[Cyberchef] Please create configure file: %s"
                     cyberchef-config-file)))
   ((not (and cyberchef-js-process cyberchef-ws-server cyberchef-ws-conn))
    (message "[Cyberchef] Process is not running, please execute `cyberchef-start'."))
   (t (let* ((cyberchef-all-config (json-read-file cyberchef-config-file))
             (candidates (mapcar (lambda (config)
                                   (cons (alist-get 'name config) config))
                                 cyberchef-all-config))
             (selected (cdr (assoc (completing-read "Select an cyberchef config: "
                                                    candidates)
                                   candidates)))
             (text (if (region-active-p)
                       (buffer-substring-no-properties
                        (region-beginning)
                        (region-end))
                     (symbol-name (symbol-at-point))))
             (text-preproc (alist-get 'text selected))
             (args-preproc (alist-get 'args selected))
             (postproc (alist-get 'res selected))
             (hint (alist-get 'hint selected))
             (bake (json-encode (alist-get 'bake selected))))
        (when text
          (when args-preproc
            (setq bake (apply 'format
                              bake
                              (mapcar (lambda (arg)
                                        (eval (car (read-from-string arg))
                                              (list (cons 'text text))))
                                      args-preproc))))
          (when text-preproc
            (setq text (eval (car (read-from-string text-preproc))
                             (list (cons 'text text)))))
          (when hint
            (if cyberchef-exec-timer
                (cancel-timer cyberchef-exec-timer)
              (setq cyberchef-exec-timer
                    (run-at-time t 1 (lambda () (message "[Cyberchef] Executing ..."))))))
          (websocket-send-text cyberchef-ws-conn
                               (json-encode (list :text text
                                                  :bake bake
                                                  :postproc postproc)))
          )))))

(provide 'cyberchef)

;;; cyberchef.el ends here
