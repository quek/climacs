;;; -*- Mode: Lisp; Package: CLIMACS-LISP-SYNTAX -*-

;;;  (c) copyright 2005 by
;;;           Robert Strandh (strandh@labri.fr)
;;;
;;; This library is free software; you can redistribute it and/or
;;; modify it under the terms of the GNU Library General Public
;;; License as published by the Free Software Foundation; either
;;; version 2 of the License, or (at your option) any later version.
;;;
;;; This library is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; Library General Public License for more details.
;;;
;;; You should have received a copy of the GNU Library General Public
;;; License along with this library; if not, write to the
;;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;;; Boston, MA  02111-1307  USA.

;;; Alternative syntax module for analysing Common Lisp

(in-package :climacs-lisp-syntax)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; the syntax object

(define-syntax lisp-syntax (basic-syntax)
  ((stack-top :initform nil)
   (potentially-valid-trees)
   (lookahead-lexeme :initform nil :accessor lookahead-lexeme)
   (current-state)
   (current-start-mark)
   (current-size)
   (scan)
   (package))
  (:name "Lisp")
  (:pathname-types "lisp" "lsp" "cl"))

(defmethod initialize-instance :after ((syntax lisp-syntax) &rest args)
  (declare (ignore args))
  (with-slots (buffer scan) syntax
     (setf scan (clone-mark (low-mark buffer) :left))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; lexer

(defgeneric skip-inter (syntax state scan)
  (:documentation "advance scan until the beginning of a new
    lexeme.  Return T if one can be found and NIL otherwise."))

(defgeneric lex (syntax state scan)
  (:documentation "Return the next lexeme starting at scan."))

(defclass lexer-state ()
  ()
  (:documentation "These states are used to determine how the lexer 
    should behave."))

(defmacro define-lexer-state (name superclasses &body body)
  `(defclass ,name (,@superclasses lexer-state)
      ,@body))

(define-lexer-state lexer-error-state ()
  ()
  (:documentation "In this state, the lexer returns error lexemes
    consisting of entire lines of text"))

(define-lexer-state lexer-toplevel-state ()
  ()
  (:documentation "In this state, the lexer assumes it can skip 
    whitespace and should recognize ordinary lexemes of the language
    except for the right parenthesis"))

(define-lexer-state lexer-list-state (lexer-toplevel-state)
  ()
  (:documentation "In this state, the lexer assumes it can skip 
    whitespace and should recognize ordinary lexemes of the language"))

(define-lexer-state lexer-string-state ()
  ()
  (:documentation "In this state, the lexer is working inside a string 
    delimited by double quote characters."))

(define-lexer-state lexer-line-comment-state ()
  ()
  (:documentation "In this state, the lexer is working inside a line 
    comment (starting with a semicolon."))

(define-lexer-state lexer-long-comment-state ()
  ()
  (:documentation "In this state, the lexer is working inside a long
    comment delimited by #| and |#."))

(define-lexer-state lexer-symbol-state ()
  ()
  (:documentation "In this state, the lexer is working inside a symbol
    delimited by | and |."))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; this should go in syntax.lisp or lr-syntax.lisp
;;; and should inherit from parse-tree

(defclass parser-symbol ()
  ((start-mark :initform nil :initarg :start-mark :reader start-mark)
   (size :initform nil :initarg :size)
   (parent :initform nil :accessor parent)
   (children :initform '() :initarg :children :reader children)
   (preceding-parse-tree :initform nil :reader preceding-parse-tree)
   (parser-state :initform nil :initarg :parser-state :reader parser-state)))

(defmethod start-offset ((state parser-symbol))
  (let ((mark (start-mark state)))
    (when mark
      (offset mark))))

(defmethod end-offset ((state parser-symbol))
  (with-slots (start-mark size) state
     (when start-mark
       (+ (offset start-mark) size))))

(defgeneric action (syntax state lexeme))
(defgeneric new-state (syntax state parser-symbol))

(defclass parser-state () ())

(defmacro define-parser-state (name superclasses &body body)
  `(progn 
     (defclass ,name ,superclasses
	  ,@body)
     (defvar ,name (make-instance ',name))))

(defclass lexeme (parser-symbol) ())

(defmethod print-object ((lexeme lexeme) stream)
  (print-unreadable-object (lexeme stream :type t :identity t)
    (format stream "~s ~s" (start-offset lexeme) (end-offset lexeme))))

(defclass nonterminal (parser-symbol) ())

(defmethod initialize-instance :after ((parser-symbol nonterminal) &rest args)
  (declare (ignore args))
  (with-slots (children start-mark size) parser-symbol
     (loop for child in children
	   do (setf (parent child) parser-symbol))
     (let ((start (find-if-not #'null children :key #'start-offset))
	   (end (find-if-not #'null children :key #'end-offset :from-end t)))
       (when start
	 (setf start-mark (slot-value start 'start-mark)
	       size (- (end-offset end) (start-offset start)))))))  

;;; until here
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass lisp-nonterminal (nonterminal) ())     
(defclass form (lisp-nonterminal) ())
(defclass incomplete-form-mixin () ())

(defclass lisp-lexeme (lexeme)
  ((ink)
   (face)))

(defclass error-lexeme (lisp-lexeme) ())
(defclass left-parenthesis-lexeme (lisp-lexeme) ())
(defclass right-parenthesis-lexeme (lisp-lexeme) ())
(defclass quote-lexeme (lisp-lexeme) ())
(defclass backquote-lexeme (lisp-lexeme) ())
(defclass comma-lexeme (lisp-lexeme) ())
(defclass form-lexeme (form lisp-lexeme) ())
(defclass token-lexeme (form-lexeme) ())
(defclass character-lexeme (form-lexeme) ())
(defclass function-lexeme (lisp-lexeme) ())
(defclass line-comment-start-lexeme (lisp-lexeme) ())
(defclass symbol-start-lexeme (lisp-lexeme) ())
(defclass symbol-end-lexeme (lisp-lexeme) ())
(defclass long-comment-start-lexeme (lisp-lexeme) ())
(defclass comment-end-lexeme (lisp-lexeme) ())
(defclass string-start-lexeme (lisp-lexeme) ())
(defclass string-end-lexeme (lisp-lexeme) ())
(defclass word-lexeme (lisp-lexeme) ())
(defclass delimiter-lexeme (lisp-lexeme) ())
(defclass text-lexeme (lisp-lexeme) ())
(defclass reader-conditional-positive-lexeme (lisp-lexeme) ())
(defclass reader-conditional-negative-lexeme (lisp-lexeme) ())
(defclass uninterned-symbol-lexeme (lisp-lexeme) ())

(defmethod skip-inter ((syntax lisp-syntax) state scan)
  (macrolet ((fo () `(forward-object scan)))
    (loop when (end-of-buffer-p scan)
	    do (return nil)
	  until (not (whitespacep (object-after scan)))
	  do (fo)
	  finally (return t))))

(defmethod lex :around (syntax state scan)
  (when (skip-inter syntax state scan)
    (let* ((start-offset (offset scan))
	   (lexeme (call-next-method))
	   (new-size (- (offset scan) start-offset)))
      (with-slots (start-mark size) lexeme
	 (setf (offset scan) start-offset)
	 (setf start-mark scan
	       size new-size))
      lexeme)))		  

(defmethod lex ((syntax lisp-syntax) (state lexer-toplevel-state) scan)
  (macrolet ((fo () `(forward-object scan)))
    (let ((object (object-after scan)))
      (case object
	(#\( (fo) (make-instance 'left-parenthesis-lexeme))
	(#\' (fo) (make-instance 'quote-lexeme))
	(#\` (fo) (make-instance 'backquote-lexeme))
	(#\, (fo) (make-instance 'comma-lexeme))
	(#\" (fo) (make-instance 'string-start-lexeme))
	(#\; (fo)
	     (loop until (or (end-of-buffer-p scan)
			     (end-of-line-p scan)
			     (not (eql (object-after scan) #\;)))
		   do (fo))
	     (make-instance 'line-comment-start-lexeme))
	(#\| (fo) (make-instance 'symbol-start-lexeme))
	(#\# (fo)
	     ( if (end-of-buffer-p scan)
		  (make-instance 'error-lexeme)
		  (case (object-after scan)
		    (#\\ (fo)
			 (cond ((end-of-buffer-p scan)
				(make-instance 'error-lexeme))
			       ((not (constituentp (object-after scan)))
				(fo) (make-instance 'character-lexeme))
			       (t (loop until (end-of-buffer-p scan)
					while (constituentp (object-after scan))
					do (fo))
				  (make-instance 'character-lexeme))))
		    (#\' (fo)
			 (make-instance 'function-lexeme))
		    (#\| (fo)
			 (make-instance 'long-comment-start-lexeme))
		    (#\+ (fo)
			 (make-instance 'reader-conditional-positive-lexeme))
		    (#\- (fo)
			 (make-instance 'reader-conditional-negative-lexeme))
		    (#\: (fo)
			 (make-instance 'uninterned-symbol-lexeme))
		    (t (fo) (make-instance 'error-lexeme)))))
	(t (cond ((constituentp object)
		  (loop until (end-of-buffer-p scan)
			while (constituentp (object-after scan))
			do (fo))
		  (make-instance 'token-lexeme))
		 (t (fo) (make-instance 'error-lexeme))))))))

(defmethod lex ((syntax lisp-syntax) (state lexer-list-state) scan)
  (macrolet ((fo () `(forward-object scan)))
    (let ((object (object-after scan)))
      (case object
	(#\) (fo) (make-instance 'right-parenthesis-lexeme))
	(t (call-next-method))))))

(defmethod lex ((syntax lisp-syntax) (state lexer-string-state) scan)
  (macrolet ((fo () `(forward-object scan)))
    (let ((object (object-after scan)))
      (cond ((eql object #\") (fo) (make-instance 'string-end-lexeme))
	    ((eql object #\\)
	     (fo)
	     (unless (end-of-buffer-p scan)
	       (fo))
	     (make-instance 'delimiter-lexeme))
	    ((constituentp object)
	     (loop until (or (end-of-buffer-p scan)
			     (not (constituentp (object-after scan))))
		   do (fo))
	     (make-instance 'word-lexeme))
	    (t (fo) (make-instance 'delimiter-lexeme))))))

(defmethod lex ((syntax lisp-syntax) (state lexer-long-comment-state) scan)
  (flet ((fo () (forward-object scan)))
    (let ((object (object-after scan)))
      (cond ((eql object #\|)
	     (fo)
	     (cond ((or (end-of-buffer-p scan)
			(not (eql (object-after scan) #\#)))
		    (make-instance 'delimiter-lexeme))
		   (t (fo) (make-instance 'comment-end-lexeme))))
	    ((eql object #\#)
	     (fo)
	     (cond ((or (end-of-buffer-p scan)
			(not (eql (object-after scan) #\|)))
		    (make-instance 'delimiter-lexeme))
		   (t (fo) (make-instance 'long-comment-start-lexeme))))
	    ((constituentp object)
	     (loop until (or (end-of-buffer-p scan)
			     (not (constituentp (object-after scan))))
		   do (fo))
	     (make-instance 'word-lexeme))
	    (t (fo) (make-instance 'delimiter-lexeme))))))

(defmethod skip-inter ((syntax lisp-syntax) (state lexer-line-comment-state) scan)
  (macrolet ((fo () `(forward-object scan)))
    (loop until (or (end-of-line-p scan)
		    (not (whitespacep (object-after scan))))
	  do (fo)
	  finally (return t))))

(defmethod lex ((syntax lisp-syntax) (state lexer-line-comment-state) scan)
  (macrolet ((fo () `(forward-object scan)))
    (cond ((end-of-line-p scan)
	   (make-instance 'comment-end-lexeme))
	  ((constituentp (object-after scan))
	   (loop until (or (end-of-buffer-p scan)
			   (not (constituentp (object-after scan))))
		 do (fo))
	   (make-instance 'word-lexeme))
	  (t (fo) (make-instance 'delimiter-lexeme)))))

(defmethod skip-inter ((syntax lisp-syntax) (state lexer-symbol-state) scan)
  (macrolet ((fo () `(forward-object scan)))
    (loop while (and (end-of-line-p scan)
		     (not (end-of-buffer-p scan)))
	  do (fo)))
  (not (end-of-buffer-p scan)))
	  
(defmethod lex ((syntax lisp-syntax) (state lexer-symbol-state) scan)
  (macrolet ((fo () `(forward-object scan)))
    (cond ((eql (object-after scan) #\|)
	   (fo)
	   (make-instance 'symbol-end-lexeme))
	  (t (loop do (cond ((or (end-of-line-p scan)
				 (eql (object-after scan) #\|))
			     (return (make-instance 'text-lexeme)))
			    ((eql (object-after scan) #\\)
			     (fo)
			     (if (end-of-line-p scan)
				 (return (make-instance 'text-lexeme))
				 (fo)))
			    (t (fo))))))))

(defmethod lex ((syntax lisp-syntax) (state lexer-error-state) scan)
  (macrolet ((fo () `(forward-object scan)))
    (loop until (end-of-line-p scan)
	  do (fo))
    (make-instance 'error-lexeme)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; nonterminals

(defclass line-comment (lisp-nonterminal) ())
(defclass long-comment (lisp-nonterminal) ())  
(defclass error-symbol (lisp-nonterminal) ())

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; parser

(defmacro define-lisp-action ((state lexeme) &body body)
  `(defmethod action ((syntax lisp-syntax) (state ,state) (lexeme ,lexeme))
     ,@body))

(defmacro define-new-lisp-state ((state parser-symbol) &body body)
  `(defmethod new-state ((syntax lisp-syntax) (state ,state) (tree ,parser-symbol))
     ,@body))

(defun pop-one (syntax)
  (with-slots (stack-top current-state) syntax
     (with-slots (preceding-parse-tree parser-state) stack-top
	(prog1 stack-top
	       (setf current-state parser-state
		     stack-top preceding-parse-tree)))))

(defun pop-number (syntax how-many)
  (loop with result = '()
	repeat how-many
	do (push (pop-one syntax) result)
	finally (return result)))

(defmacro reduce-fixed-number (symbol nb-children)
  `(let ((result (make-instance ',symbol :children (pop-number syntax ,nb-children))))
     (when (zerop ,nb-children)
       (with-slots (scan) syntax
	  (with-slots (start-mark size) result
	     (setf start-mark (clone-mark scan :right)
		   size 0))))
     result))

(defun pop-until-type (syntax type)
  (with-slots (stack-top) syntax
     (loop with result = '()
	   for child = stack-top
	   do (push (pop-one syntax) result)
	   until (typep child type)
	   finally (return result))))

(defmacro reduce-until-type (symbol type)
  `(let ((result (make-instance ',symbol
		    :children (pop-until-type syntax ',type))))
     (when (null (children result))
       (with-slots (scan) syntax
	  (with-slots (start-mark size) result
	     (setf start-mark (clone-mark scan :right)
		   size 0))))
     result))

(defun pop-all (syntax)
  (with-slots (stack-top) syntax
     (loop with result = '()
	   until (null stack-top)
	   do (push (pop-one syntax) result)
	   finally (return result))))

(defmacro reduce-all (symbol)
  `(let ((result (make-instance ',symbol :children (pop-all syntax))))
     (when (null (children result))
       (with-slots (scan) syntax
	  (with-slots (start-mark size) result
	     (setf start-mark (clone-mark scan :right)
		   size 0))))
     result))     

(define-parser-state error-state (lexer-error-state parser-state) ())
(define-parser-state error-reduce-state (lexer-toplevel-state parser-state) ())

(define-lisp-action (error-reduce-state (eql nil))
  (throw 'done nil)) 

;;; the default action for any lexeme is shift
(define-lisp-action (t lisp-lexeme)
  lexeme)

;;; the action on end-of-buffer is to reduce to the error symbol
(define-lisp-action (t (eql nil))
  (reduce-all error-symbol))

;;; the default new state is the error state
(define-new-lisp-state (t parser-symbol) error-state)

;;; the new state when an error-state 
(define-new-lisp-state (t error-symbol) error-reduce-state)


;;;;;;;;;;;;;;;; Top-level 

#| rules
   form* -> 
   form* -> form* form
|#

;;; parse trees
(defclass form* (lisp-nonterminal) ())

(define-parser-state |form* | (lexer-toplevel-state parser-state) ())
(define-parser-state form-may-follow (lexer-toplevel-state parser-state) ())
(define-parser-state |initial-state | (form-may-follow) ())

(define-new-lisp-state (|initial-state | form) |initial-state |)

(define-lisp-action (|initial-state | (eql nil))
  (reduce-all form*))

(define-new-lisp-state (|initial-state | form*) |form* | )
  
(define-lisp-action (|form* | (eql nil))
  (throw 'done nil))

;;;;;;;;;;;;;;;; List

#| rules
   form -> ( form* )
|#

;;; parse trees
(defclass list-form (form) ())
(defclass complete-list-form (list-form) ())
(defclass incomplete-list-form (list-form incomplete-form-mixin) ())

(define-parser-state |( form* | (lexer-list-state form-may-follow) ())
(define-parser-state |( form* ) | (lexer-toplevel-state parser-state) ())

(define-new-lisp-state (form-may-follow left-parenthesis-lexeme) |( form* |)
(define-new-lisp-state (|( form* | form) |( form* |)
(define-new-lisp-state (|( form* | right-parenthesis-lexeme) |( form* ) |)

;;; reduce according to the rule form -> ( form* )
(define-lisp-action (|( form* ) | t)
  (reduce-until-type complete-list-form left-parenthesis-lexeme))

;;; reduce at the end of the buffer
(define-lisp-action (|( form* | (eql nil))
  (reduce-until-type incomplete-list-form left-parenthesis-lexeme))

;;;;;;;;;;;;;;;; String

;;; parse trees
(defclass string-form (form) ())
(defclass complete-string-form (string-form) ())
(defclass incomplete-string-form (string-form incomplete-form-mixin) ())

(define-parser-state |" word* | (lexer-string-state parser-state) ())
(define-parser-state |" word* " | (lexer-toplevel-state parser-state) ())

(define-new-lisp-state (|" word* | word-lexeme) |" word* |)
(define-new-lisp-state (|" word* | delimiter-lexeme) |" word* |)
(define-new-lisp-state (form-may-follow string-start-lexeme) |" word* |)
(define-new-lisp-state (|" word* | string-end-lexeme) |" word* " |)

;;; reduce according to the rule form -> " word* "
(define-lisp-action (|" word* " | t)
  (reduce-until-type complete-string-form string-start-lexeme))

;;; reduce at the end of the buffer 
(define-lisp-action (|" word* | (eql nil))
  (reduce-until-type incomplete-string-form string-start-lexeme))

;;;;;;;;;;;;;;;; Line comment

;;; parse trees
(defclass line-comment-form (form) ())

(define-parser-state |; word* | (lexer-line-comment-state parser-state) ())
(define-parser-state |; word* NL | (lexer-toplevel-state parser-state) ())

(define-new-lisp-state (form-may-follow line-comment-start-lexeme) |; word* |)
(define-new-lisp-state (|; word* | word-lexeme) |; word* |)
(define-new-lisp-state (|; word* | delimiter-lexeme) |; word* |)
(define-new-lisp-state (|; word* | comment-end-lexeme) |; word* NL |)

;;; reduce according to the rule form -> ; word* NL
(define-lisp-action (|; word* NL | t)
  (reduce-until-type line-comment-form line-comment-start-lexeme))

;;;;;;;;;;;;;;;; Long comment

;; FIXME  this does not work for nested comments

;;; parse trees
(defclass long-comment-form (form) ())
(defclass complete-long-comment-form (long-comment-form) ())
(defclass incomplete-long-comment-form (long-comment-form incomplete-form-mixin) ())

(define-parser-state |#\| word* | (lexer-long-comment-state parser-state) ())
(define-parser-state |#\| word* \|# | (lexer-toplevel-state parser-state) ())

(define-new-lisp-state (|#\| word* | word-lexeme) |#\| word* |)
(define-new-lisp-state (|#\| word* | delimiter-lexeme) |#\| word* |)
(define-new-lisp-state (|#\| word* | long-comment-start-lexeme) |#\| word* |)
(define-new-lisp-state (|#\| word* | long-comment-form) |#\| word* |)
(define-new-lisp-state (form-may-follow long-comment-start-lexeme) |#\| word* |)
(define-new-lisp-state (|#\| word* | comment-end-lexeme) |#\| word* \|# |)

;;; reduce according to the rule form -> #| word* |#
(define-lisp-action (|#\| word* \|# | t)
  (reduce-until-type complete-long-comment-form long-comment-start-lexeme))

;;; reduce at the end of the buffer
(define-lisp-action (|#\| word* | (eql nil))
  (reduce-until-type incomplete-long-comment-form long-comment-start-lexeme))

;;;;;;;;;;;;;;;; Symbol name surrounded with vertical bars

;;; parse trees
(defclass symbol-form (form) ())
(defclass complete-symbol-form (symbol-form) ())
(defclass incomplete-symbol-form (symbol-form incomplete-form-mixin) ())

(define-parser-state |\| text* | (lexer-symbol-state parser-state) ())
(define-parser-state |\| text* \| | (lexer-toplevel-state parser-state) ())

(define-new-lisp-state (form-may-follow symbol-start-lexeme) |\| text* |)
(define-new-lisp-state (|\| text* | text-lexeme) |\| text* |)
(define-new-lisp-state (|\| text* | symbol-end-lexeme) |\| text* \| |)

;;; reduce according to the rule form -> | text* |
(define-lisp-action (|\| text* \| | t)
  (reduce-until-type complete-symbol-form symbol-start-lexeme))

;;; reduce at the end of the buffer
(define-lisp-action (|\| text* | (eql nil))
  (reduce-until-type incomplete-symbol-form symbol-start-lexeme))

;;;;;;;;;;;;;;;; Quote

;;; parse trees
(defclass quote-form (form) ())

(define-parser-state |' | (form-may-follow) ())
(define-parser-state |' form | (lexer-toplevel-state parser-state) ())

(define-new-lisp-state (form-may-follow quote-lexeme) |' |)
(define-new-lisp-state (|' | form) |' form |)

;;; reduce according to the rule form -> ' form
(define-lisp-action (|' form | t)
  (reduce-fixed-number quote-form 2))

;;;;;;;;;;;;;;;; Backquote

;;; parse trees
(defclass backquote-form (form) ())

(define-parser-state |` | (form-may-follow) ())
(define-parser-state |` form | (lexer-toplevel-state parser-state) ())

(define-new-lisp-state (form-may-follow backquote-lexeme) |` |)
(define-new-lisp-state (|` | form) |` form |)

;;; reduce according to the rule form -> ` form
(define-lisp-action (|` form | t)
  (reduce-fixed-number backquote-form 2))

;;;;;;;;;;;;;;;; Comma

;;; parse trees
(defclass comma-form (form) ())

(define-parser-state |, | (form-may-follow) ())
(define-parser-state |, form | (lexer-toplevel-state parser-state) ())

(define-new-lisp-state (form-may-follow comma-lexeme) |, |)
(define-new-lisp-state (|, | form) |, form |)

;;; reduce according to the rule form -> , form
(define-lisp-action (|, form | t)
  (reduce-fixed-number backquote-form 2))

;;;;;;;;;;;;;;;; Function

;;; parse trees
(defclass function-form (form) ())

(define-parser-state |#' | (form-may-follow) ())
(define-parser-state |#' form | (lexer-toplevel-state parser-state) ())

(define-new-lisp-state (form-may-follow function-lexeme) |#' |)
(define-new-lisp-state (|#' | form) |#' form |)

;;; reduce according to the rule form -> #' form
(define-lisp-action (|#' form | t)
  (reduce-fixed-number function-form 2))

;;;;;;;;;;;;;;;; Reader conditionals

;;; parse trees
(defclass reader-conditional-positive-form (form) ())
(defclass reader-conditional-negative-form (form) ())

(define-parser-state |#+ | (form-may-follow) ())
(define-parser-state |#+ form | (form-may-follow) ())
(define-parser-state |#+ form form | (lexer-toplevel-state parser-state) ())
(define-parser-state |#- | (form-may-follow) ())
(define-parser-state |#- form | (form-may-follow) ())
(define-parser-state |#- form form | (lexer-toplevel-state parser-state) ())

(define-new-lisp-state (form-may-follow reader-conditional-positive-lexeme) |#+ |)
(define-new-lisp-state (|#+ | form) |#+ form |)
(define-new-lisp-state (|#+ form | form) |#+ form form |)
(define-new-lisp-state (form-may-follow reader-conditional-negative-lexeme) |#- |)
(define-new-lisp-state (|#- | form) |#- form |)
(define-new-lisp-state (|#- form | form) |#- form form |)
  
(define-lisp-action (|#+ form form | t)
  (reduce-fixed-number reader-conditional-positive-form 3))

(define-lisp-action (|#- form form | t)
  (reduce-fixed-number reader-conditional-negative-form 3))

;;;;;;;;;;;;;;;; uninterned symbol

;;; parse trees
(defclass uninterned-symbol-form (form) ())

(define-parser-state |#: | (form-may-follow) ())
(define-parser-state |#: form | (lexer-toplevel-state parser-state) ())

(define-new-lisp-state (form-may-follow uninterned-symbol-lexeme) |' |)
(define-new-lisp-state (|#: | form) |#: form |)

;;; reduce according to the rule form -> #: form
(define-lisp-action (|#: form | t)
  (reduce-fixed-number uninterned-symbol-form 2))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; parser step

(defgeneric parser-step (syntax))

(defmethod parser-step ((syntax lisp-syntax))
  (with-slots (lookahead-lexeme stack-top current-state scan) syntax
     (setf lookahead-lexeme (lex syntax current-state (clone-mark scan :right)))
     (let* ((new-parser-symbol (action syntax current-state lookahead-lexeme))
	    (new-state (new-state syntax current-state new-parser-symbol)))
       (with-slots (parser-state parser-symbol preceding-parse-tree children) new-parser-symbol
	  (setf parser-state current-state
		current-state new-state
		preceding-parse-tree stack-top
		stack-top new-parser-symbol)))
     (setf (offset scan) (end-offset stack-top))))

(defun prev-tree (tree)
  (assert (not (null tree)))
  (if (null (children tree))
      (preceding-parse-tree tree)
      (car (last (children tree)))))

(defun next-tree (tree)
  (assert (not (null tree)))
  (if (null (parent tree))
      nil
      (let* ((parent (parent tree))
	     (siblings (children parent)))
	(cond ((null parent) nil)
	      ((eq tree (car (last siblings))) parent)
	      (t (loop with new-tree = (cadr (member tree siblings :test #'eq))
		       until (null (children new-tree))
		       do (setf new-tree (car (children new-tree)))
		       finally (return new-tree)))))))	 

(defun find-last-valid-lexeme (parse-tree offset)
  (cond ((or (null parse-tree) (null (start-offset parse-tree))) nil)
	((> (start-offset parse-tree) offset)
	 (find-last-valid-lexeme (preceding-parse-tree parse-tree) offset))
	((not (typep parse-tree 'lexeme))
	 (find-last-valid-lexeme (car (last (children parse-tree))) offset))
	((>= (end-offset parse-tree) offset)
	 (find-last-valid-lexeme (preceding-parse-tree parse-tree) offset))
	(t parse-tree)))  

(defun find-first-potentially-valid-lexeme (parse-trees offset)
  (cond ((null parse-trees) nil)
	((or (null (start-offset (car parse-trees)))
	     (< (end-offset (car parse-trees)) offset))
	 (find-first-potentially-valid-lexeme (cdr parse-trees) offset))
	((not (typep (car parse-trees) 'lexeme))
	 (find-first-potentially-valid-lexeme (children (car parse-trees)) offset))
	((< (start-offset (car parse-trees)) offset)
	 (loop with tree = (next-tree (car parse-trees))
	       until (or (null tree) (>= (start-offset tree) offset))
	       do (setf tree (next-tree tree))
	       finally (return tree)))
	(t (car parse-trees))))

(defun parse-tree-equal (tree1 tree2)
  (and (eq (class-of tree1) (class-of tree2))
       (eq (parser-state tree1) (parser-state tree2))
       (= (end-offset tree1) (end-offset tree2))))

(defmethod print-object ((mark mark) stream)
  (print-unreadable-object (mark stream :type t :identity t)
    (format stream "~s" (offset mark))))

(defun parse-patch (syntax)
  (with-slots (current-state stack-top scan potentially-valid-trees) syntax
     (parser-step syntax)
     (finish-output *trace-output*)
     (cond ((parse-tree-equal stack-top potentially-valid-trees)
	    (unless (or (null (parent potentially-valid-trees))
			(eq potentially-valid-trees
			    (car (last (children (parent potentially-valid-trees))))))
	      (loop for tree = (cadr (member potentially-valid-trees
					     (children (parent potentially-valid-trees))
					     :test #'eq))
		      then (car (children tree))
		    until (null tree)
		    do (setf (slot-value tree 'preceding-parse-tree)
			     stack-top))
	      (setf stack-top (prev-tree (parent potentially-valid-trees))))
	    (setf potentially-valid-trees (parent potentially-valid-trees))
	    (setf current-state (new-state syntax (parser-state stack-top) stack-top))
	    (setf (offset scan) (end-offset stack-top)))
	   (t (loop until (or (null potentially-valid-trees)
			      (>= (start-offset potentially-valid-trees)
				  (end-offset stack-top)))
		    do (setf potentially-valid-trees
			     (next-tree potentially-valid-trees)))))))	    

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; update syntax

(defmethod update-syntax-for-display (buffer (syntax lisp-syntax) top bot)
  nil)

(defun package-of (syntax)
  (let ((buffer (buffer syntax)))
    (flet ((test (x)
	     (and (typep x 'list-form)
		  (not (null (cdr (children x))))
		  (buffer-looking-at buffer
				     (start-offset (cadr (children x)))
				     "in-package"
				     :test #'char-equal))))
      (with-slots (stack-top) syntax
	(let ((form (find-if #'test (children stack-top))))
	  (and form
	       (not (null (cddr (children form))))
	       (let* ((package-form (caddr (children form)))
		      (package-name (coerce (buffer-sequence
					     buffer
					     (start-offset package-form)
					     (end-offset package-form))
					    'string))
		      (package-symbol
		       (let ((*package* (find-package :common-lisp)))
			 (ignore-errors
			   (read-from-string package-name nil nil)))))
		 (find-package package-symbol))))))))

(defmethod update-syntax (buffer (syntax lisp-syntax))
  (let* ((low-mark (low-mark buffer))
	 (high-mark (high-mark buffer)))
    (when (mark<= low-mark high-mark)
      (catch 'done
	(with-slots (current-state stack-top scan potentially-valid-trees) syntax
	   (setf potentially-valid-trees
		 (if (null stack-top)
		     nil
		     (find-first-potentially-valid-lexeme (children stack-top)
							  (offset high-mark))))
	   (setf stack-top (find-last-valid-lexeme stack-top (offset low-mark)))
	   (setf (offset scan) (if (null stack-top) 0 (end-offset stack-top))
		 current-state (if (null stack-top)
				   |initial-state |
				   (new-state syntax
					      (parser-state stack-top)
					      stack-top)))
	   (loop do (parse-patch syntax))))))
  (with-slots (package) syntax
    (setf package (package-of syntax))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; display

(defvar *white-space-start* nil)

(defvar *cursor-positions* nil)
(defvar *current-line* 0)

(defun handle-whitespace (pane buffer start end)
  (let ((space-width (space-width pane))
	(tab-width (tab-width pane)))
    (loop while (< start end)
       do (ecase (buffer-object buffer start)
	    (#\Newline (terpri pane)
		       (setf (aref *cursor-positions* (incf *current-line*))
			     (multiple-value-bind (x y) (stream-cursor-position pane)
			       (declare (ignore x))
			       y)))
	    (#\Space (stream-increment-cursor-position
		      pane space-width 0))
	    (#\Tab (let ((x (stream-cursor-position pane)))
		     (stream-increment-cursor-position
		      pane (- tab-width (mod x tab-width)) 0))))
	 (incf start))))		    

(defgeneric display-parse-tree (parse-symbol syntax pane))

(defmethod display-parse-tree ((parse-symbol (eql nil)) syntax pane)
  nil)

(defmethod display-parse-tree :around (parse-symbol syntax pane)
  (with-slots (top bot) pane
     (when (and (start-offset parse-symbol) 
		(mark< (start-offset parse-symbol) bot)
		(mark> (end-offset parse-symbol) top))
       (call-next-method))))  

(defmethod display-parse-tree (parse-symbol syntax pane)
  (loop for child in (children parse-symbol)
	do (display-parse-tree child syntax pane)))

(defmethod display-parse-tree ((parse-symbol error-symbol) (syntax lisp-syntax) pane)
  (let ((children (children parse-symbol)))
    (loop until (or (null (cdr children))
		    (typep (parser-state (cadr children)) 'error-state))
	  do (display-parse-tree (pop children) syntax pane))
    (if (and (null (cdr children))
	     (not (typep (parser-state parse-symbol) 'error-state)))
	(display-parse-tree (car children) syntax pane)
	(with-drawing-options (pane :ink +red+)
	  (loop for child in children
		do (display-parse-tree child syntax pane))))))

(defmethod display-parse-tree ((parse-symbol error-lexeme) (syntax lisp-syntax) pane)
  (with-drawing-options (pane :ink +red+)
    (call-next-method)))

(defmethod display-parse-tree ((parse-symbol token-lexeme) (syntax lisp-syntax) pane)
  (if (and (> (end-offset parse-symbol) (start-offset parse-symbol))
	   (eql (buffer-object (buffer syntax) (start-offset parse-symbol)) #\:))
      (with-drawing-options (pane :ink +dark-violet+)
	(call-next-method))
      (call-next-method)))

(defmethod display-parse-tree ((parser-symbol lisp-lexeme) (syntax lisp-syntax) pane)
  (flet ((cache-test (t1 t2)
	   (and (eq t1 t2)
		(eq (slot-value t1 'ink)
		    (medium-ink (sheet-medium pane)))
		(eq (slot-value t1 'face)
		    (text-style-face (medium-text-style (sheet-medium pane)))))))
    (updating-output
	(pane :unique-id parser-symbol
	      :id-test #'eq
	      :cache-value parser-symbol
	      :cache-test #'cache-test)
      (with-slots (ink face) parser-symbol
	(setf ink (medium-ink (sheet-medium pane))
	      face (text-style-face (medium-text-style (sheet-medium pane))))
	(let ((string (coerce (buffer-sequence (buffer syntax)
					       (start-offset parser-symbol)
					       (end-offset parser-symbol))
			      'string)))
	  (multiple-value-bind (symbol status)
	      (token-to-symbol syntax parser-symbol)
	    (declare (ignore symbol))
	    (if (and status (typep parser-symbol 'form))
		(present string 'symbol :stream pane)
		(present string 'string :stream pane))))))))

(defmethod display-parse-tree :before ((parse-symbol lisp-lexeme) (syntax lisp-syntax) pane)
  (handle-whitespace pane (buffer pane) *white-space-start* (start-offset parse-symbol))
  (setf *white-space-start* (end-offset parse-symbol)))

(defmethod display-parse-tree ((parse-symbol complete-string-form) (syntax lisp-syntax) pane)
  (let ((children (children parse-symbol)))
    (display-parse-tree  (pop children) syntax pane)
    (with-text-face (pane :italic)
      (loop until (null (cdr children))
	    do (display-parse-tree (pop children) syntax pane)))
    (display-parse-tree (pop children) syntax pane)))

(defmethod display-parse-tree ((parse-symbol incomplete-string-form) (syntax lisp-syntax) pane)
  (let ((children (children parse-symbol)))
    (display-parse-tree  (pop children) syntax pane)
    (with-text-face (pane :italic)
      (loop until (null children)
	    do (display-parse-tree (pop children) syntax pane)))))

(defmethod display-parse-tree ((parse-symbol line-comment-form) (syntax lisp-syntax) pane)
  (with-drawing-options (pane :ink +maroon+)
    (call-next-method)))

(defmethod display-parse-tree ((parse-symbol long-comment-form) (syntax lisp-syntax) pane)
  (with-drawing-options (pane :ink +maroon+)
    (call-next-method)))
    
(defmethod display-parse-tree ((parse-symbol complete-list-form) (syntax lisp-syntax) pane)
  (let ((children (children parse-symbol)))
    (if (= (end-offset parse-symbol) (offset (point pane)))
	(with-text-face (pane :bold)
	  (display-parse-tree (car children) syntax pane))
	(display-parse-tree (car children) syntax pane))
    (loop for child in (cdr children)
	  do (display-parse-tree child syntax pane))))
    
(defmethod display-parse-tree ((parse-symbol symbol-form) (syntax lisp-syntax) pane)
  (call-next-method))

(defmethod redisplay-pane-with-syntax ((pane climacs-pane) (syntax lisp-syntax) current-p)
  (declare (ignore current-p))
  (with-slots (top bot) pane
     (setf *cursor-positions* (make-array (1+ (number-of-lines-in-region top bot)))
	   *current-line* 0
	   (aref *cursor-positions* 0) (stream-cursor-position pane))
     (setf *white-space-start* (offset top)))
  (with-slots (stack-top) syntax
     (display-parse-tree stack-top syntax pane))
  (with-slots (top) pane
    (let* ((cursor-line (number-of-lines-in-region top (point pane)))
	   (height (text-style-height (medium-text-style pane) pane))
	   (cursor-y (+ (* cursor-line (+ height (stream-vertical-spacing pane)))))
	   (cursor-column 
	    (buffer-display-column
	     (buffer (point pane)) (offset (point pane))
	     (round (tab-width pane) (space-width pane))))
	   (cursor-x (* cursor-column (text-style-width (medium-text-style pane) pane))))
      (updating-output (pane :unique-id -1)
	(draw-rectangle* pane
			 (1- cursor-x) (- cursor-y (* 0.2 height))
			 (+ cursor-x 2) (+ cursor-y (* 0.8 height))
			 :ink (if current-p +red+ +blue+))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; exploit the parse 

(defun form-before-in-children (children offset)
  (loop for (first second) on children
	do (cond ((< (start-offset first) offset (end-offset first))
		  (return (if (null (children first))
			      nil
			      (form-before-in-children (children first) offset))))
		 ((and (>= offset (end-offset first))
		       (or (null second)
			   (<= offset (start-offset second))))
		  (return (let ((potential-form (form-before-in-children (children first) offset)))
			    (or potential-form
				(when (typep first 'form)
				  first)))))
		 (t nil))))
		 
(defun form-before (syntax offset)
  (with-slots (stack-top) syntax
    (if (or (null (start-offset stack-top))
	    (<= offset (start-offset stack-top)))
	nil
	(form-before-in-children (children stack-top) offset))))

(defun form-after-in-children (children offset)
  (loop for child in children
	do (cond ((< (start-offset child) offset (end-offset child))
		  (return (if (null (children child))
			      nil
			      (form-after-in-children (children child) offset))))
		 ((<= offset (start-offset child))
		  (return (let ((potential-form (form-after-in-children (children child) offset)))
			    (or potential-form
				(when (typep child 'form)
				  child)))))
		 (t nil))))
		 
(defun form-after (syntax offset)
  (with-slots (stack-top) syntax
    (if (or (null (start-offset stack-top))
	    (>= offset (end-offset stack-top)))
	nil
	(form-after-in-children (children stack-top) offset))))
	     
(defun form-around-in-children (children offset)
  (loop for child in children
	do (cond ((< (start-offset child) offset (end-offset child))
		  (return (if (null (children child))
			      (when (typep child 'form)
				child)
			      (form-around-in-children (children child) offset))))
		 ((<= offset (start-offset child))
		  (return nil))
		 (t nil))))
		 
(defun form-around (syntax offset)
  (with-slots (stack-top) syntax
    (if (or (null (start-offset stack-top))
	    (>= offset (end-offset stack-top))
	    (<= offset (start-offset stack-top)))
	nil
	(form-around-in-children (children stack-top) offset))))

(defmethod backward-expression (mark (syntax lisp-syntax))
  (let ((potential-form (or (form-before syntax (offset mark))
			    (form-around syntax (offset mark)))))
    (if potential-form
	(setf (offset mark) (start-offset potential-form))
	(error 'no-expression))))

(defmethod forward-expression (mark (syntax lisp-syntax))
  (let ((potential-form (or (form-after syntax (offset mark))
			    (form-around syntax (offset mark)))))
    (if potential-form
	(setf (offset mark) (end-offset potential-form))
	(error 'no-expression))))

(defmethod eval-defun (mark (syntax lisp-syntax))
  (with-slots (stack-top) syntax
     (loop for form in (children stack-top)
	   when (and (mark<= (start-offset form) mark)
		     (mark<= mark (end-offset form)))
	     do (return (eval (read-from-string 
			       (coerce (buffer-sequence (buffer syntax)
							(start-offset form)
							(end-offset form))
				       'string)))))))

;;; shamelessly stolen from SWANK

(defconstant keyword-package (find-package :keyword)
  "The KEYWORD package.")

;; FIXME: deal with #\| etc.  hard to do portably.
(defun tokenize-symbol (string)
  (let ((package (let ((pos (position #\: string)))
                   (if pos (subseq string 0 pos) nil)))
        (symbol (let ((pos (position #\: string :from-end t)))
                  (if pos (subseq string (1+ pos)) string)))
        (internp (search "::" string)))
    (values symbol package internp)))

(defun determine-case (string)
  "Return two booleans LOWER and UPPER indicating whether STRING
contains lower or upper case characters."
  (values (some #'lower-case-p string)
          (some #'upper-case-p string)))

;; FIXME: Escape chars are ignored
(defun casify (string)
  "Convert string accoring to readtable-case."
  (ecase (readtable-case *readtable*)
    (:preserve string)
    (:upcase   (string-upcase string))
    (:downcase (string-downcase string))
    (:invert (multiple-value-bind (lower upper) (determine-case string)
               (cond ((and lower upper) string)
                     (lower (string-upcase string))
                     (upper (string-downcase string))
                     (t string))))))

(defun parse-symbol (string &optional (package *package*))
  "Find the symbol named STRING.
Return the symbol and a flag indicating whether the symbols was found."
  (multiple-value-bind (sname pname) (tokenize-symbol string)
    (let ((package (cond ((string= pname "") keyword-package)
                         (pname              (find-package (casify pname)))
                         (t                  package))))
      (if package
          (find-symbol (casify sname) package)
          (values nil nil)))))


(defun token-to-symbol (syntax token)
  (let ((package (or (slot-value syntax 'package)
		     (find-package :common-lisp)))
	(token-string (coerce (buffer-sequence (buffer syntax)
					       (start-offset token)
					       (end-offset token))
			      'string)))
    (parse-symbol token-string package)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; indentation

(defmethod indent-form ((syntax lisp-syntax) (tree form*) path)
  (cond ((or (null path)
	     (and (null (cdr path)) (zerop (car path))))
	 (values tree 0))
	((null (cdr path))
	 (values (elt (children tree) (1- (car path))) 0))
	(t (indent-form syntax (elt (children tree) (car path)) (cdr path)))))

(defmethod indent-form ((syntax lisp-syntax) (tree list-form) path)
  (if (= (car path) 1)
      ;; before first element
      (values tree 1)
      (let ((first-child (elt (children tree) 1)))
	(cond ((and (typep first-child 'token-lexeme)
		    (token-to-symbol syntax first-child))
	       (compute-list-indentation syntax (token-to-symbol syntax first-child) tree path))
	      ((null (cdr path))
	       ;; top level
	       (if (= (car path) 2)
		   ;; indent like first element
		   (values (elt (children tree) 1) 0)
		   ;; indent like second element
		   (values (elt (children tree) 2) 0)))
	      (t
	       ;; inside a subexpression
	       (indent-form syntax (elt (children tree) (car path)) (cdr path)))))))	    

(defmethod indent-form ((syntax lisp-syntax) (tree string-form) path)
  (values tree 1))

(defmethod indent-binding ((syntax lisp-syntax) tree path)
  (if (null (cdr path))
      ;; top level
      (cond ((= (car path) 1)
	     ;; before variable, indent 1
	     (values tree 1))
	    ((= (car path) 2)
	     ;; between variable and value
	     (values (elt (children tree) 1) 0))
	    (t
	     ;; after value
	     (values (elt (children tree) 2) 0)))
      (indent-form syntax (elt (children tree) (car path)) (cdr path))))

(defmethod indent-bindings ((syntax lisp-syntax) tree path)
  (if (null (cdr path))
      ;; entire bind form
      (if (= (car path) 1)
	  ;; before first binding, indent 1
	  (values tree 1)
	  ;; after some bindings, align with first binding
	  (values (elt (children tree) 1) 0))
      ;; inside a bind form
      (indent-binding syntax (elt (children tree) (car path)) (cdr path))))

(defmethod compute-list-indentation ((syntax lisp-syntax) symbol tree path)
  (if (null (cdr path))
      ;; top level
      (if (= (car path) 2)
	  ;; indent like first child
	  (values (elt (children tree) 1) 0)
	  ;; indent like second child
	  (values (elt (children tree) 2) 0))
      ;; inside a subexpression
      (indent-form syntax (elt (children tree) (car path)) (cdr path))))

(defmacro define-list-indentor (name element-indentor)
  `(defun ,name (syntax tree path)
     (if (null (cdr path))
	 ;; top level
	 (if (= (car path) 1)
	     ;; indent one more than the list
	     (values tree 1)
	     ;; indent like the first element
	     (values (elt (children tree) 1) 0))
	 ;; inside an element
	 (,element-indentor syntax (elt (children tree) (car path)) (cdr path)))))

;;; line up the elements vertically
(define-list-indentor indent-list indent-list)

;;; for now the same as indent-list, but try to do better with
;;; optional parameters with default values
(define-list-indentor indent-lambda-list indent-list)

(defmacro define-simple-indentor (template)
  `(defmethod compute-list-indentation
       ((syntax lisp-syntax) (symbol (eql ',(car template))) tree path)
     (cond ((null (cdr path))
	    (values tree (if (<= (car path) ,(length template)) 4 2)))
	   ,@(loop for fun in (cdr template)
		  for i from 2
		  collect `((= (car path) ,i) (,fun syntax (elt (children tree) ,i) (cdr path))))
	   (t (indent-form syntax (elt (children tree) (car path)) (cdr path))))))

(define-simple-indentor (prog1 indent-form))
(define-simple-indentor (let indent-bindings))
(define-simple-indentor (let* indent-bindings))
(define-simple-indentor (defun indent-list indent-lambda-list))
(define-simple-indentor (defmacro indent-list indent-lambda-list))
(define-simple-indentor (with-slots indent-list))
(define-simple-indentor (when indent-form))
(define-simple-indentor (unless indent-form))

;;; do this better 
(define-list-indentor indent-slot-specs indent-list)

(defmethod compute-list-indentation
    ((syntax lisp-syntax) (symbol (eql 'defclass)) tree path)
  (if (null (cdr path))
      ;; top level
      (values tree (if (<= (car path) 3) 4 2))
      (case (car path)
	((2 3)
	 ;; in the class name or superclasses respectively
	 (indent-list syntax (elt (children tree) (car path)) (cdr path)))
	(4
	 ;; in the slot specs 
	 (indent-slot-specs syntax (elt (children tree) 4) (cdr path)))
	(t
	 ;; this is an approximation, might want to do better
	 (indent-list syntax (elt (children tree) (car path)) (cdr path))))))

(defmethod compute-list-indentation
    ((syntax lisp-syntax) (symbol (eql 'defgeneric)) tree path)
  (if (null (cdr path))
      ;; top level
      (values tree (if (<= (car path) 3) 4 2))
      (case (car path)
	(2
	 ;; in the function name
	 (indent-list syntax (elt (children tree) 2) (cdr path)))
	(3
	 ;; in the lambda-list
	 (indent-lambda-list syntax (elt (children tree) 3) (cdr path)))
	(t
	 ;; in the options or method specifications
	 (indent-list syntax (elt (children tree) (car path)) (cdr path))))))

(defmethod compute-list-indentation
    ((syntax lisp-syntax) (symbol (eql 'defmethod)) tree path)
  (let ((lambda-list-pos (position-if (lambda (x) (typep x 'list-form))
				      (children tree))))
    (cond ((null (cdr path))
	   ;; top level
	   (values tree (if (or (null lambda-list-pos)
				(<= (car path) lambda-list-pos))
			    4
			    2)))
	  ((or (null lambda-list-pos)
	       (< (car path) lambda-list-pos))
	   (indent-list syntax (elt (children tree) (car path)) (cdr path)))
	  ((= (car path) lambda-list-pos)
	   (indent-lambda-list syntax (elt (children tree) (car path)) (cdr path)))
	  (t
	   (indent-form syntax (elt (children tree) (car path)) (cdr path))))))

(define-list-indentor indent-clause indent-form)

(defmethod compute-list-indentation
    ((syntax lisp-syntax) (symbol (eql 'cond)) tree path)
  (if (null (cdr path))
      ;; top level
      (if (= (car path) 2)
	  ;; after `cond' 
	  (values tree 2)
	  ;; indent like the first clause
	  (values (elt (children tree) 2) 0))
      ;; inside a clause
      (indent-clause syntax (elt (children tree) (car path)) (cdr path))))

(defun compute-path-in-trees (trees n offset)
  (cond ((or (null trees)
	     (>= (start-offset (car trees)) offset))    
	 (list n))
	((or (< (start-offset (car trees)) offset (end-offset (car trees)))
	     (typep (car trees) 'incomplete-form-mixin))
	 (cons n (compute-path-in-tree (car trees) offset)))
	(t (compute-path-in-trees (cdr trees) (1+ n) offset))))

(defun compute-path-in-tree (tree offset)
  (if (null (children tree))
      '()
      (compute-path-in-trees (children tree) 0 offset)))

(defun compute-path (syntax offset)
  (with-slots (stack-top) syntax
    (compute-path-in-tree stack-top offset)))

(defun real-column-number (mark tab-width)
  (let ((mark2 (clone-mark mark)))
    (beginning-of-line mark2)
    (loop with column = 0
	  until (mark= mark mark2)
	  do (if (eql (object-after mark2) #\Tab)
		 (loop do (incf column)
		       until (zerop (mod column tab-width)))
		 (incf column))
	  do (incf (offset mark2))
          finally (return column))))

(defmethod syntax-line-indentation (mark tab-width (syntax lisp-syntax))
  (setf mark (clone-mark mark))
  (beginning-of-line mark)
  (with-slots (stack-top) syntax
    (let ((path (compute-path syntax (offset mark))))
      (multiple-value-bind (tree offset)
	  (indent-form syntax stack-top path)
	(setf (offset mark) (start-offset tree))
	(+ (real-column-number mark tab-width)
	   offset)))))
