;;; emacspeak-google.el --- Google Search Tools
;;; $Id: emacspeak-google.el 4797 2007-07-16 23:31:22Z tv.raman.tv $
;;; $Author: tv.raman.tv $
;;; Description:  Speech-enable GOOGLE An Emacs Interface to google
;;; Keywords: Emacspeak,  Audio Desktop google
;;{{{  LCD Archive entry:

;;; LCD Archive Entry:
;;; emacspeak| T. V. Raman |raman@cs.cornell.edu
;;; A speech interface to Emacs |
;;; $Date: 2007-05-03 18:13:44 -0700 (Thu, 03 May 2007) $ |
;;;  $Revision: 4532 $ |
;;; Location undetermined
;;;

;;}}}
;;{{{  Copyright:
;;;Copyright (C) 1995 -- 2011, T. V. Raman
;;; Copyright (c) 1994, 1995 by Digital Equipment Corporation.
;;; All Rights Reserved.
;;;
;;; This file is not part of GNU Emacs, but the same permissions apply.
;;;
;;; GNU Emacs is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 2, or (at your option)
;;; any later version.
;;;
;;; GNU Emacs is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNGOOGLE FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Emacs; see the file COPYING.  If not, write to
;;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

;;}}}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;{{{  introduction

;;; Commentary:
;;; There are a number of search tools that can be implemented on
;;; the Google search page --- in a JS-powered browser, these
;;; show up as the Google tool-belt.
;;; This module implements a minor mode for use in Google result
;;; pages that enables these tools via single keyboard commands.
;;; Originally all options were available as tbs=p:v
;;; Now, some specialized searches, e.g. blog search are tbm=
;;; Code:

;;}}}
;;{{{  Required modules

(require 'cl)
(declaim  (optimize  (safety 0) (speed 3)))
(require 'emacspeak-preamble)
(require 'gweb)
(require 'derived)
(require 'html2text)
;;}}}
;;{{{ Data Structures 

;;; One tool on a tool-belt

(defstruct emacspeak-google-tool
  name ; human readable
  param ; url param bit
  range ; range of possible values
  default
  value ; current setting
  type ;tbs/tbm
  )

(defvar emacspeak-google-query nil
  "Current Google Query.
This variable is buffer-local.")
(make-variable-buffer-local 'emacspeak-google-query)

(defvar emacspeak-google-toolbelt nil
  "List of tools on the toolbelt.")

(make-variable-buffer-local 'emacspeak-google-toolbelt)

(defun emacspeak-google-toolbelt-to-tbm (belt)
  "Return value for use in tbm parameter in search queries."
  (let
      ((settings
        (delq nil
              (mapcar 
               #'(lambda (tool)
                   (when (eq 'tbm (emacspeak-google-tool-type tool))
                     (cond
                      ((equal (emacspeak-google-tool-value tool)
                              (emacspeak-google-tool-default tool))
                       nil)
                      (t (format "%s"
                                 (emacspeak-google-tool-param tool))))))
               belt))))
    (when settings 
      (concat "&tbm="
              (mapconcat #'identity settings ",")))))

(defun emacspeak-google-toolbelt-to-tbs (belt)
  "Return value for use in tbs parameter in search queries."
  (let
      ((settings
        (delq nil
              (mapcar 
               #'(lambda (tool)
                   (when (eq 'tbs (emacspeak-google-tool-type tool))
                     (cond
                      ((equal (emacspeak-google-tool-value tool)
                              (emacspeak-google-tool-default tool))
                       nil)
                      (t (format "%s:%s"
                                 (emacspeak-google-tool-param tool)
                                 (emacspeak-google-tool-value tool))))))
               belt))))
    (when settings 
      (concat "&tbs="
              (mapconcat #'identity settings ",")))))

(defun emacspeak-google-toolbelt ()
  "Returns buffer-local toolbelt or a a newly initialized toolbelt."
  (declare (special emacspeak-google-toolbelt))
  (or emacspeak-google-toolbelt
      (list
;;; video vid: 1/0
       (make-emacspeak-google-tool
        :name "video"
        :param "vid"
        :range '(0 1)
        :default 0
        :type 'tbm
        :value 0)
;;; Recent
       (make-emacspeak-google-tool
        :name "recent"
        :param "rcnt"
        :range '( 0 1)
        :default 0
        :value 0
        :type 'tbs)
;;; Duration restrict for video
       (make-emacspeak-google-tool
        :name "duration"
        :param "dur"
        :range '("m" "s" "l")
        :default "m"
        :value "m"
        :type 'tbs)
;;; Blog mode
       (make-emacspeak-google-tool
        :name "blog"
        :param "blg"
        :range '(0 1)
        :default 0
        :value 0
        :type 'tbm)
;;; Books mode
       (make-emacspeak-google-tool
        :name "books"
        :param "bks"
        :range '(0 1)
        :default 0
        :type 'tbm
        :value 0)
;;; epub 
       (make-emacspeak-google-tool
        :name "books-format"
        :param "bft"
        :range '("p" "e")
        :default "e"
        :type 'tbs
        :value "e")
;;; Books viewability
       (make-emacspeak-google-tool
        :name "books-viewability"
        :param "bkv"
        :range '("a" "f")
        :default "a"
        :value "a"
        :type 'tbs)
;;; Book Type
       (make-emacspeak-google-tool
        :name "books-type"
        :param "bkt"
        :range '("b" "p" "m")
        :default "b"
        :value "b"
        :type 'tbs)
;;; Forums Mode
       (make-emacspeak-google-tool
        :name "forums"
        :param "frm"
        :range '(0 1)
        :default 0
        :value 0
        :type 'tbs)
;;; News Mode
       (make-emacspeak-google-tool
        :name "news"
        :param "nws"
        :range '(0 1)
        :default 0
        :value 0
        :type 'tbm)
;;; Reviews
       (make-emacspeak-google-tool
        :name "reviews"
        :param "rvw"
        :range '(0 1)
        :default 0
        :value 0
        :type 'tbs)
;;; Web History Visited
       (make-emacspeak-google-tool
        :name "web-history-visited"
        :param "whv"
        :range '(0 1)
        :default 0
        :type 'tbs
        :value 0)
;;; Web History Not Visited
       (make-emacspeak-google-tool
        :name "web-history-not-visited"
        :param "whnv"
        :type 'tbs
        :range '(0 1)
        :default 0
        :value 0)
;;; Images
       (make-emacspeak-google-tool
        :name "images"
        :param "isch"
        :range '(0 1)
        :default 0
        :value 0
        :type 'tbm)
;;; Structured Snippets
       (make-emacspeak-google-tool
        :name "structured-snippets"
        :param "sts"
        :range '(0 1)
        :default 0
        :value 0
        :type 'tbs)
;;; sort by date
       (make-emacspeak-google-tool
        :name "sort-by-date"
        :param "std"
        :range '(0 1)
        :default 0
        :value 0
        :type 'tbs)
;;; Timeline
       (make-emacspeak-google-tool
        :name "timeline"
        :param "tl"
        :range '(0 1)
        :default 0
        :type 'tbs
        :value 0)
;;; Timeline Low
       (make-emacspeak-google-tool
        :name "timeline-low"
        :param "tll"
        :type 'tbs
        :range "YYYY/MM"
        :default ""
        :value "")
;;; Date Filter
       (make-emacspeak-google-tool
        :name "date-filter"
        :param "qdr"
        :range "tn"
        :default ""
        :type 'tbs
        :value "")
;;; Timeline High
       (make-emacspeak-google-tool
        :name "timeline-high"
        :param "tlh"
        :range "YYYY/MM"
        :default ""
        :type 'tbs
        :value "")
;;; more:commercial promotion with prices
       (make-emacspeak-google-tool
        :name "commercial"
        :param "cpk"
        :range '(0 1)
        :default 0
        :type 'tbs
        :value 0)
;;; verbatim/literal search
       (make-emacspeak-google-tool
        :name "literal"
        :param "li"
        :range '(0 1)
        :default 0
        :type 'tbs
        :value 0)
       ;;; shopping
       (make-emacspeak-google-tool
        :name "Shopping"
        :param "shop"
        :range '(0 1)
        :default 0
        :type 'tbm
        :value 0)
       (make-emacspeak-google-tool
        :name "commercial-prices"
        :param "cp"
        :range '(0 1)
        :default 0
        :type 'tbs
        :value 0)
;;; less:commercial (demotion)
       (make-emacspeak-google-tool
        :name "non-commercial" 
        :param "cdcpk"
        :range '(0 1)
        :default 0
        :type 'tbs
        :value 0)
       ;;; soc
       (make-emacspeak-google-tool
        :name "social" 
        :param "sa"
        :range '(0 1)
        :default 0
        :type 'tbs
        :value 0))))

;;}}}
;;{{{ Interactive Commands

(loop for this-tool in
      (emacspeak-google-toolbelt)
      do
      (eval
       `(defun
          ,(intern
            (format
             "emacspeak-google-toolbelt-change-%s"
             (emacspeak-google-tool-name this-tool)))
          ()
          ,(format
            "Change  %s in the currently active toolbelt."
            (emacspeak-google-tool-name this-tool))
          (interactive)
          (let*
              ((belt (emacspeak-google-toolbelt))
               (tool
                (find-if #'(lambda (tool) (string-equal (emacspeak-google-tool-name tool)
                                                        ,(emacspeak-google-tool-name this-tool)))
                         belt))
               (param (emacspeak-google-tool-param tool))
               (value (emacspeak-google-tool-value tool))
               (range (emacspeak-google-tool-range tool)))
            (cond
             ((and (listp range)
                   (= 2 (length range)))
;;; toggle value
              (setf (emacspeak-google-tool-value tool)
                    (if (equal value (first range))
                        (second range)
                      (first range))))
             ((listp range)
;;; Prompt using completion
              (setf  (emacspeak-google-tool-value tool)
                     (completing-read
                      "Set tool to: "
                      range)))
             ((stringp range)
              (setf (emacspeak-google-tool-value tool)
                    (read-from-minibuffer  range)))
             (t (error "Unexpected type!")))
            (let
                ((emacspeak-websearch-google-options
                  (concat
                   (emacspeak-google-toolbelt-to-tbs belt)
                   (emacspeak-google-toolbelt-to-tbm belt))))
              (emacspeak-websearch-google
               (or emacspeak-google-query
                   (gweb-google-autocomplete))))))))

(defun emacspeak-google-show-toolbelt()
  "Reload search page with toolbelt showing."
  (interactive)
  (declare (special emacspeak-google-query))
  (let ((emacspeak-websearch-google-options "&tbo=1"))
    (emacspeak-websearch-google emacspeak-google-query)))

;;}}}
;;{{{  keymap
;;;###autoload
(define-prefix-command  'emacspeak-google-command
  'emacspeak-google-keymap)

(loop for k in
      '(
        ("h"
         emacspeak-google-toolbelt-change-web-history-visited)
        ("H" emacspeak-google-toolbelt-change-web-history-not-visited)
        ("r" emacspeak-google-toolbelt-change-recent)
        ("b" emacspeak-google-toolbelt-change-blog)
        ("n" emacspeak-google-toolbelt-change-news)
        ("c" emacspeak-google-toolbelt-change-commercial)
        ("d" emacspeak-google-toolbelt-change-sort-by-date)
        ("p" emacspeak-google-toolbelt-change-commercial-prices)
        ("f" emacspeak-google-toolbelt-change-forums)
        ("v" emacspeak-google-toolbelt-change-video)
        ("i" emacspeak-google-toolbelt-change-images)
        ("B" emacspeak-google-toolbelt-change-books)
        ("t" emacspeak-google-toolbelt-change-books-type)
        ("L" emacspeak-google-toolbelt-change-literal)
        ("\C-t" emacspeak-google-show-toolbelt)
        ("T" emacspeak-google-toolbelt-change-timeline)
        ("\C-b" emacspeak-google-toolbelt-change-books-format)
        ("l" emacspeak-google-toolbelt-change-non-commercial)
        ("S" emacspeak-google-toolbelt-change-shopping)
        ("s" emacspeak-google-toolbelt-change-structured-snippets)
        ("S" emacspeak-google-toolbelt-change-social)
        ("a" emacspeak-websearch-google)
        ("A" emacspeak-websearch-accessible-google)
        )
      do
      (emacspeak-keymap-update emacspeak-google-keymap k))

;;}}}
;;{{{ Google Maps API V3

;;; See  https://developers.google.com/maps/documentation/directions/
(defvar emacspeak-google-maps-modes '("driving" "walking" "bicycling" "transit")
  "Supported modes for getting directions.")


(defun emacspeak-google-maps-routes (origin destination mode)
  "Return routes as found by Google Maps Directions."
  (let ((result
         (g-json-get-result
          (format "%s --max-time 2 --connect-timeout 1 %s '%s'"
                  g-curl-program g-curl-common-options
                  (gweb-maps-directions-url
                   (emacspeak-url-encode origin)
                   (emacspeak-url-encode destination)
                   mode)))))
    (cond
     ((string= "OK" (g-json-get 'status result)) (g-json-get 'routes result))
     (t (error "Status %s from Maps" (g-json-get 'status result))))))


;;; https://developers.google.com/places/

(defcustom emacspeak-google-maps-places-key nil
  "Places API  key --- goto  https://code.google.com/apis/console to get one."
  :type '(choice
          (const :tag "None" nil)
          (string :value ""))
  :group 'emacspeak-google)


;;}}}
;;{{{ Maps UI: 

(defvar emacspeak-google-maps-current-location
       (and (boundp 'gweb-my-location)
                 gweb-my-location)
      "Current maps location.")

(make-variable-buffer-local
 'emacspeak-google-maps-current-location)


(define-derived-mode emacspeak-google-maps-mode special-mode
  "Google Maps Interaction"
  "A Google Maps front-end for the Emacspeak desktop."
  (let ((start (point))
        (inhibit-read-only t))
    (setq buffer-undo-list t)
    (goto-char (point-min))
    (insert "Google Maps Interaction")
    (put-text-property start (point) 'face font-lock-doc-face)
    (insert "\n\f\n")
    (setq header-line-format "Google Maps")))

(declaim (special emacspeak-google-maps-mode-map))

(loop for k in
      '(
        ("d" emacspeak-google-maps-driving-directions)
        ("w" emacspeak-google-maps-walking-directions)
        ("t" emacspeak-google-maps-transit-directions)
        ("b" emacspeak-google-maps-bicycling-directions)
        ("n" emacspeak-google-maps-places-nearby)
        ("s" emacspeak-google-maps-places-search)
        ("c" emacspeak-google-maps-set-current-location)
        )
      do
      (define-key  emacspeak-google-maps-mode-map (first k) (second k)))

(defvar emacspeak-google-maps-interaction-buffer "*Google Maps*"
  "Google Maps interaction buffer.")

(defun emacspeak-google-maps ()
  "Google Maps Interaction."
  (interactive)
  (declare (special emacspeak-google-maps-interaction-buffer))
  (let ((buffer (get-buffer emacspeak-google-maps-interaction-buffer)))
    (cond
     ((buffer-live-p buffer) (switch-to-buffer buffer))
     (t
      (with-current-buffer (get-buffer-create emacspeak-google-maps-interaction-buffer)
        (erase-buffer)
        (emacspeak-google-maps-mode)
        (setq buffer-read-only t))
      (switch-to-buffer emacspeak-google-maps-interaction-buffer)))
    (emacspeak-auditory-icon 'open-object)
    (emacspeak-speak-mode-line)))


(defun emacspeak-google-maps-display-leg (leg)
  "Display a leg of a route."
  (let ((i 1)
        (inhibit-read-only t)
        (start (point)))
    (loop for step across (g-json-get 'steps leg)
          do
          (insert
           (format "%d:\t%-40ss\t%s\t%s\n"
                   i
                   (g-json-get  'html_instructions step)
                   (g-json-get 'text (g-json-get 'distance step))
                   (g-json-get 'text (g-json-get 'duration step))))
          (save-excursion
            (save-restriction
              (narrow-to-region start (point))
              (html2text)))
          (put-text-property start (1- (point))
                             'maps-data step)
          (setq start  (point))
          (incf i))))

(defun emacspeak-google-maps-display-route (route)
  "Display route in a Maps buffer."
  (let ((i 1)
        (inhibit-read-only t)
        (length (length  (g-json-get 'legs route)))
        (leg nil))
    (insert
     (format "Summary: %s\n"
             (g-json-get 'summary route)))
    (cond
     ((= 1 length)
      (setq leg (aref (g-json-get 'legs route) 0))
      (insert (format "From %s to %s\n%s\t%s\n"
                      (g-json-get 'start_address leg)
                      (g-json-get 'end_address leg)
                      (g-json-get 'text (g-json-get 'distance leg))
                      (g-json-get 'text (g-json-get 'duration leg))))
      (emacspeak-google-maps-display-leg (aref (g-json-get 'legs route) 0)))
     (t
      (loop for leg across (g-json-get 'legs route)
            do
            (insert (format "Leg:%d: From %s to %s\n"
                            i
                            (g-json-get 'start_address leg)
                            (g-json-get 'end_address)))
            (emacspeak-google-maps-display-leg leg)
            (incf i))))
    (insert
     (format "Warnings: %s\n"
             (g-json-get 'warnings route)))
    (insert
     (format "Copyrights: %s\n\f\n"
             (g-json-get 'copyrights route)))))

(defun emacspeak-google-maps-display-routes (routes)
  "Display routes in Maps interaction buffer."
  (let ((i 1)
        (length (length routes))
        (inhibit-read-only t))
    (cond
     ((= 1 length) (emacspeak-google-maps-display-route (aref routes 0)))
     (t
      (loop for route across routes
            do
            (insert (format  "\nRoute %d\n" i))
            (incf i)
            (emacspeak-google-maps-display-route route))))))


(defun emacspeak-google-maps-driving-directions (origin destination)
  "Driving directions from Google Maps."
  (interactive "sStart Address: \nsDestination Address: ")
  (emacspeak-google-maps-directions origin destination "driving"))

(defun emacspeak-google-maps-walking-directions (origin destination)
  "Walking directions from Google Maps."
  (interactive "sStart Address: \nsDestination Address: ")
  (emacspeak-google-maps-directions origin destination "walking"))

(defun emacspeak-google-maps-bicycling-directions (origin destination)
  "Biking directions from Google Maps."
  (interactive "sStart Address: \nsDestination Address: ")
  (emacspeak-google-maps-directions origin destination "bicycling"))


(defun emacspeak-google-maps-transit-directions (origin destination)
  "Transit directions from Google Maps."
  (interactive "sStart Address: \nsDestination Address: ")
  (emacspeak-google-maps-directions origin destination "transit"))



(defun emacspeak-google-maps-directions (origin destination mode)
  "Display  directions obtained from Google Maps."
  (interactive
   (list
    (read-from-minibuffer "Start Address: ")
    (read-from-minibuffer "Destination Address: ")
    (completing-read "Mode: " emacspeak-google-maps-modes)))
  (unless (eq major-mode 'emacspeak-google-maps-mode)
    (error "Not in a Maps buffer."))
  (let ((inhibit-read-only t)
        (start (point-max))
        (routes (emacspeak-google-maps-routes origin destination mode)))
    (goto-char (point-max))
    (insert (format "%s Directions\n" (capitalize mode)))
        (when routes (emacspeak-google-maps-display-routes routes))
        (goto-char start)
        (emacspeak-auditory-icon 'task-done)
        (emacspeak-speak-rest-of-buffer)))

(defun emacspeak-google-maps-places-nearby  (&optional radius)
  "Perform a places nearby search.
Uses `emacspeak-google-maps-current-location' for the start location."
  (interactive "p")
  (or radius (setq radius 500))
  (let  ((maps-data (get-text-property (point) 'maps-data))
         (location nil)
         (search-type nil)
         (search-query nil))
    (cond
     (maps-data (setq location (g-json-get 'start_location maps-data)))
      (t
       (setq location
             (gweb-maps-geocode
              (emacspeak-url-encode
               (read-from-minibuffer "Address: "))))))
    (setq location
             (format "%s,%s"
                              (g-json-get 'lat location)
                              (g-json-get 'lng location)))))
     
(defun emacspeak-google-maps-set-current-location ()
  "Set current location."
  (interactive )
  (declare (special emacspeak-google-maps-current-location))
  (let ((address (read-from-minibuffer "Current Address:")))
    (setq emacspeak-google-maps-current-location
          (gweb-maps-geocode address))
    (put 'emacspeak-google-maps-current-location 'address address)))
;;}}}
(provide 'emacspeak-google)
;;{{{ end of file

;;; local variables:
;;; folded-file: t
;;; byte-compile-dynamic: nil
;;; end:

;;}}}
