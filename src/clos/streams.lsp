;;;;  -*- Mode: Lisp; Syntax: Common-Lisp; Package: CLOS -*-
;;;;
;;;;  Copyright (c) 2004, Juan Jose Garcia-Ripoll
;;;;
;;;;    This program is free software; you can redistribute it and/or
;;;;    modify it under the terms of the GNU Library General Public
;;;;    License as published by the Free Software Foundation; either
;;;;    version 2 of the License, or (at your option) any later version.
;;;;
;;;;    See file '../Copyright' for full details.
;;;;        The CLOS IO library.

(in-package "GRAY")

;;;
;;; This is the generic function interface for CLOS streams.
;;;
;;; The following is a port of SBCL's implementation of Gray Streams. Minor
;;; caveats with respect to the proposal are that we rather keep CLOSE,
;;; STREAM-ELEMENT-TYPE, INPUT-STREAM-P, OUTPUT-STREAM-P and OPEN-STREAM-P
;;; these as normal functions that call the user extensible EXT:STREAM-{CLOSE,
;;; ELT-TYPE, INPUT-P, OUTPUT-P, OPEN-P}.
;;;

(defgeneric stream-advance-to-column (stream column)
  (:documentation
   "Write enough blank space so that the next character will be
  written at the specified column. Returns true if the operation is
  successful, or NIL if it is not supported for this stream. This is
  intended for use by by PPRINT and FORMAT ~T. The default method uses
  STREAM-LINE-COLUMN and repeated calls to STREAM-WRITE-CHAR with a
  #\SPACE character; it returns NIL if STREAM-LINE-COLUMN returns NIL."))

(defgeneric stream-clear-input (stream)
  (:documentation
   "This is like CL:CLEAR-INPUT, but for Gray streams, returning NIL.
  The default method does nothing."))

(defgeneric stream-clear-output (stream)
  (:documentation
   "This is like CL:CLEAR-OUTPUT, but for Gray streams: clear the given
  output STREAM. The default method does nothing."))

(defgeneric close (stream &key abort)
  (:documentation
   "Close the given STREAM. No more I/O may be performed, but
  inquiries may still be made. If :ABORT is true, an attempt is made
  to clean up the side effects of having created the stream."))

(defgeneric stream-element-type (stream)
  (:documentation
   "Return a type specifier for the kind of object returned by the
  STREAM. The class FUNDAMENTAL-CHARACTER-STREAM provides a default method
  which returns CHARACTER."))

(defgeneric stream-finish-output (stream)
  (:documentation
   "Attempts to ensure that all output sent to the Stream has reached
  its destination, and only then returns false. Implements
  FINISH-OUTPUT. The default method does nothing."))

(defgeneric stream-force-output (stream)
  (:documentation
   "Attempts to force any buffered output to be sent. Implements
  FORCE-OUTPUT. The default method does nothing."))

(defgeneric stream-fresh-line (stream)
  (:documentation
   "Outputs a new line to the Stream if it is not positioned at the
  begining of a line. Returns T if it output a new line, nil
  otherwise. Used by FRESH-LINE. The default method uses
  STREAM-START-LINE-P and STREAM-TERPRI."))

(defgeneric input-stream-p (stream)
  (:documentation "Can STREAM perform input operations?"))

(defgeneric stream-p (stream)
  (:documentation "Is this object a STREAM?"))

(defgeneric stream-interactive-p (stream)
  (:documentation "Is stream interactive (For instance, a tty)?"))

(defgeneric stream-line-column (stream)
  (:documentation
   "Return the column number where the next character
  will be written, or NIL if that is not meaningful for this stream.
  The first column on a line is numbered 0. This function is used in
  the implementation of PPRINT and the FORMAT ~T directive. For every
  character output stream class that is defined, a method must be
  defined for this function, although it is permissible for it to
  always return NIL."))

(defgeneric stream-listen (stream)
  #+sb-doc
  (:documentation
   "This is used by LISTEN. It returns true or false. The default method uses
  STREAM-READ-CHAR-NO-HANG and STREAM-UNREAD-CHAR. Most streams should
  define their own method since it will usually be trivial and will
  always be more efficient than the default method."))

(defgeneric open-stream-p (stream)
  (:documentation
   "Return true if STREAM is not closed. A default method is provided
  by class FUNDAMENTAL-STREAM which returns true if CLOSE has not been
  called on the stream."))

(defgeneric output-stream-p (stream)
  (:documentation "Can STREAM perform output operations?"))

(defgeneric stream-peek-char (stream)
  (:documentation
   "This is used to implement PEEK-CHAR; this corresponds to PEEK-TYPE of NIL.
  It returns either a character or :EOF. The default method calls
  STREAM-READ-CHAR and STREAM-UNREAD-CHAR."))

(defgeneric stream-read-byte (stream)
  (:documentation
   "Used by READ-BYTE; returns either an integer, or the symbol :EOF
  if the stream is at end-of-file."))

(defgeneric stream-read-char (stream)
  (:documentation
   "Read one character from the stream. Return either a
  character object, or the symbol :EOF if the stream is at end-of-file.
  Every subclass of FUNDAMENTAL-CHARACTER-INPUT-STREAM must define a
  method for this function."))

(defgeneric stream-read-char-no-hang (stream)
  (:documentation
   "This is used to implement READ-CHAR-NO-HANG. It returns either a
  character, or NIL if no input is currently available, or :EOF if
  end-of-file is reached. The default method provided by
  FUNDAMENTAL-CHARACTER-INPUT-STREAM simply calls STREAM-READ-CHAR; this
  is sufficient for file streams, but interactive streams should define
  their own method."))

(defgeneric stream-read-line (stream)
  (:documentation
   "This is used by READ-LINE. A string is returned as the first value. The
  second value is true if the string was terminated by end-of-file
  instead of the end of a line. The default method uses repeated
  calls to STREAM-READ-CHAR."))

(defgeneric stream-read-sequence (stream seq &optional start end)
  (:documentation
   "This is like CL:READ-SEQUENCE, but for Gray streams."))

(defgeneric stream-start-line-p (stream)
  (:documentation
   "Is STREAM known to be positioned at the beginning of a line?
  It is permissible for an implementation to always return
  NIL. This is used in the implementation of FRESH-LINE. Note that
  while a value of 0 from STREAM-LINE-COLUMN also indicates the
  beginning of a line, there are cases where STREAM-START-LINE-P can be
  meaningfully implemented although STREAM-LINE-COLUMN can't be. For
  example, for a window using variable-width characters, the column
  number isn't very meaningful, but the beginning of the line does have
  a clear meaning. The default method for STREAM-START-LINE-P on class
  FUNDAMENTAL-CHARACTER-OUTPUT-STREAM uses STREAM-LINE-COLUMN, so if
  that is defined to return NIL, then a method should be provided for
  either STREAM-START-LINE-P or STREAM-FRESH-LINE."))

(defgeneric stream-terpri (stream)
  (:documentation
   "Writes an end of line, as for TERPRI. Returns NIL. The default
  method does (STREAM-WRITE-CHAR stream #\NEWLINE)."))

(defgeneric stream-unread-char (stream character)
  (:documentation
   "Un-do the last call to STREAM-READ-CHAR, as in UNREAD-CHAR.
  Return NIL. Every subclass of FUNDAMENTAL-CHARACTER-INPUT-STREAM
  must define a method for this function."))

(defgeneric stream-write-byte (stream integer)
  (:documentation
   "Implements WRITE-BYTE; writes the integer to the stream and
  returns the integer as the result."))

(defgeneric stream-write-char (stream character)
  (:documentation
   "Write CHARACTER to STREAM and return CHARACTER. Every
  subclass of FUNDAMENTAL-CHARACTER-OUTPUT-STREAM must have a method
  defined for this function."))

(defgeneric stream-write-string (stream string &optional start end)
  (:documentation
   "This is used by WRITE-STRING. It writes the string to the stream,
  optionally delimited by start and end, which default to 0 and NIL.
  The string argument is returned. The default method provided by
  FUNDAMENTAL-CHARACTER-OUTPUT-STREAM uses repeated calls to
  STREAM-WRITE-CHAR."))

(defgeneric stream-write-sequence (stream seq &optional start end)
  (:documentation
   "This is like CL:WRITE-SEQUENCE, but for Gray streams."))


;;;
;;; Our class hierarchy looks like the one from Gray streams
;;;
;;; character output streams
;;;
;;; A character output stream can be created by defining a class that
;;; includes FUNDAMENTAL-CHARACTER-OUTPUT-STREAM and defining methods
;;; for the generic functions below.
;;;
;;; binary streams
;;;
;;; Binary streams can be created by defining a class that includes
;;; either FUNDAMENTAL-BINARY-INPUT-STREAM or
;;; FUNDAMENTAL-BINARY-OUTPUT-STREAM (or both) and defining a method
;;; for STREAM-ELEMENT-TYPE and for one or both of the following
;;; generic functions.
;;;

(defclass fundamental-stream (standard-object stream)
  ((open-p :initform t :accessor open-stream-p))
  (:documentation "the base class for all CLOS streams"))

(defclass fundamental-input-stream (fundamental-stream) nil)

(defclass fundamental-output-stream (fundamental-stream) nil)

(defclass fundamental-character-stream (fundamental-stream) nil)

(defclass fundamental-binary-stream (fundamental-stream) nil)

(defclass fundamental-character-input-stream
    (fundamental-input-stream fundamental-character-stream) nil)

(defclass fundamental-character-output-stream
    (fundamental-output-stream fundamental-character-stream) nil)

(defclass fundamental-binary-input-stream
    (fundamental-input-stream fundamental-binary-stream) nil)

(defclass fundamental-binary-output-stream
    (fundamental-output-stream fundamental-binary-stream) nil)


;;;
;;; The following methods constitute default implementations.
;;;

(defun bug-or-error (stream fun)
  (declare (ext::c-local))
  (error "The stream ~S has no suitable method for ~S." stream fun))

;; STREAM-ADVANCE-TO-COLUMN

(defmethod stream-advance-to-column ((stream fundamental-character-output-stream)
				     column)
  (let ((current-column (stream-line-column stream)))
    (when current-column
      (let ((fill (- column current-column)))
	(dotimes (i fill)
	  (stream-write-char stream #\Space)))
      T)))


;; CLEAR-INPUT

(defmethod stream-clear-input ((stream fundamental-character-input-stream))
  nil)
(defmethod stream-clear-input ((stream stream))
  (bug-or-error stream 'stream-clear-input))
(defmethod stream-clear-input ((non-stream t))
  (error 'type-error :datum non-stream :expected-type 'stream))


;; CLEAR-OUTPUT

(defmethod stream-clear-output ((stream fundamental-output-stream))
  nil)
(defmethod stream-clear-output ((stream stream))
  (bug-or-error stream 'stream-clear-output))
(defmethod stream-clear-output ((non-stream t))
  (error 'type-error :datum non-stream :expected-type 'stream))


;; CLOSE

(defmethod close ((stream fundamental-stream) &key abort)
  (declare (ignore abort))
  (setf (open-stream-p stream) nil)
  t)

(defmethod close ((stream stream) &key abort)
  (cl:close stream :abort abort))

(defmethod close ((non-stream t) &key abort)
  (declare (ignore abort))
  (error 'type-error :datum non-stream :expected-type 'stream))

;; STREAM-ELEMENT-TYPE

(defmethod stream-element-type ((stream fundamental-character-stream))
  'character)

(defmethod stream-element-type ((stream fundamental-stream))
  (bug-or-error stream 'stream-element-type))

(defmethod stream-element-type ((stream stream))
  (cl:stream-element-type stream))

(defmethod stream-element-type ((non-stream t))
  (error 'type-error :datum non-stream :expected-type 'stream))


;; FINISH-OUTPUT

(defmethod stream-finish-output ((stream fundamental-output-stream))
  nil)
(defmethod stream-finish-output ((stream stream))
  (bug-or-error stream 'stream-finish-output))
(defmethod stream-finish-output ((non-stream t))
  (error 'type-error :datum non-stream :expected-type 'stream))


;; FORCE-OUTPUT

(defmethod stream-force-output ((stream fundamental-output-stream))
  nil)
(defmethod stream-force-output ((stream stream))
  (bug-or-error stream 'stream-force-output))
(defmethod stream-force-output ((non-stream t))
  (error 'type-error :datum non-stream :expected-type 'stream))


;; FRESH-LINE

(defmethod stream-fresh-line ((stream fundamental-character-output-stream))
  (unless (stream-start-line-p stream)
    (stream-terpri stream)
    t))


;; INPUT-STREAM-P

(defmethod input-stream-p ((stream fundamental-stream))
  nil)

(defmethod input-stream-p ((stream fundamental-input-stream))
  t)

(defmethod input-stream-p ((stream stream))
  (cl:input-stream-p stream))

(defmethod input-stream-p ((non-stream t))
  (error 'type-error :datum non-stream :expected-type 'stream))


;; INTERACTIVE-STREAM-P

(defmethod stream-interactive-p ((stream stream))
  (bug-or-error stream 'stream-interactive-p))

(defmethod stream-interactive-p ((non-stream t))
  (error 'type-error :datum non-stream :expected-type 'stream))

;; LINE-COLUMN

(defmethod stream-line-column ((stream fundamental-character-output-stream))
   nil)


;; LISTEN

(defmethod stream-listen ((stream fundamental-character-input-stream))
  (let ((char (stream-read-char-no-hang stream)))
    (when (characterp char)
      (stream-unread-char stream char)
      t)))


;; OPEN-STREAM-P

(defmethod open-stream-p ((stream stream))
  (cl:open-stream-p stream))

(defmethod open-stream-p ((non-stream t))
  (error 'type-error :datum non-stream :expected-type 'stream))


;; OUTPUT-STREAM-P

(defmethod output-stream-p ((stream fundamental-stream))
  nil)

(defmethod output-stream-p ((stream fundamental-output-stream))
  t)

(defmethod output-stream-p ((stream stream))
  (cl:output-stream-p stream))

(defmethod output-stream-p ((non-stream t))
  (error 'type-error :datum non-stream :expected-type 'stream))


;; PEEK-CHAR

(defmethod stream-peek-char ((stream fundamental-character-input-stream))
  (let ((char (stream-read-char stream)))
    (unless (eq char :eof)
      (stream-unread-char stream char))
    char))


;; READ-BYTE

(defmethod stream-read-byte ((stream stream))
  (bug-or-error stream 'stream-read-byte))
(defmethod stream-read-byte ((non-stream t))
  (error 'type-error :datum non-stream :expected-type 'stream))


;; READ-CHAR-NO-HANG

(defmethod stream-read-char-no-hang ((stream fundamental-character-input-stream))
  (stream-read-char stream))


;; READ-LINE

(defmethod stream-read-line ((stream fundamental-character-input-stream))
  (let ((res (make-string 80))
	(len 80)
	(index 0))
    (loop
     (let ((ch (stream-read-char stream)))
       (cond ((eq ch :eof)
	      (return (values (shrink-vector res index) t)))
	     (t
	      (when (char= ch #\newline)
		(return (values (shrink-vector res index) nil)))
	      (when (= index len)
		(setq len (* len 2))
		(let ((new (make-string len)))
		  (replace new res)
		  (setq res new)))
	      (setf (schar res index) ch)
	      (incf index)))))))


;; READ-SEQUENCE

(defmethod stream-read-sequence ((stream fundamental-character-input-stream)
                                 (seq sequence)
                                 &optional (start 0) (end nil))
  (si::do-read-sequence seq stream start end))

(defmethod stream-read-sequence ((stream fundamental-binary-input-stream)
                                 (seq sequence)
                                 &optional (start 0) (end nil))
  (si::do-read-sequence seq stream start end))


;; START-LINE-P

(defmethod stream-start-line-p ((stream fundamental-character-output-stream))
  (eql (stream-line-column stream) 0))


;; STREAM-P

(defmethod streamp ((stream stream))
  t)

(defmethod streamp ((no-stream t))
  nil)

;; WRITE-BYTE

(defmethod stream-write-byte ((stream stream) integer)
  (bug-or-error stream 'stream-write-byte))
(defmethod stream-write-byte ((non-stream t) integer)
  (error 'type-error :datum non-stream :expected-type 'stream))


;; WRITE-SEQUENCE

(defmethod stream-write-sequence ((stream fundamental-character-output-stream)
                                  (seq sequence)
                                  &optional (start 0) (end nil))
  (si::do-write-sequence seq stream start end))

(defmethod stream-write-sequence ((stream fundamental-binary-output-stream)
                                  (seq sequence)
                                  &optional (start 0) (end nil))
  (si::do-write-sequence seq stream start end))

;; WRITE-STRING

(defmethod stream-write-string ((stream fundamental-character-output-stream)
				string &optional (start 0) end)
  (declare (string string)
	   (fixnum start))
  (let ((end (or end (length string))))
    (declare (fixnum end))
    (do ((pos start (1+ pos)))
	((>= pos end))
      (declare (type index pos))
      (stream-write-char stream (aref string pos))))
  string)


;; TERPRI

(defmethod stream-terpri ((stream fundamental-character-output-stream))
  (stream-write-char stream #\Newline))

(let ((p (find-package "GRAY")))
  (do-external-symbols (s (find-package "COMMON-LISP"))
    (unless (member s '(cl:close cl:stream-element-type cl:input-stream-p
			cl:open-stream-p cl:output-stream-p cl:streamp))
      (export s p))))

