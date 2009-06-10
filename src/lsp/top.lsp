;;;;  -*- Mode: Lisp; Syntax: Common-Lisp; Package: SYSTEM -*-
;;;;
;;;;  top.lsp -- Top-level loop, break loop, and error handlers
;;;;
;;;;  Copyright (c) 1990, Giuseppe Attardi.
;;;;
;;;;    This program is free software; you can redistribute it and/or
;;;;    modify it under the terms of the GNU Library General Public
;;;;    License as published by the Free Software Foundation; either
;;;;    version 2 of the License, or (at your option) any later version.
;;;;
;;;;    See file '../Copyright' for full details.
;;;;
;;;;  Revised on July 11, by Carl Hoffman.
;;;;  Modified Oct 1986 by Ken Rimey.
;;;;  Reworked March 1987, by Edward Wang.
;;;;  Merged into new distribution Sept 1987, by Edward Wang.
;;;;  Reworked for Threads November 1988, by Giuseppe Attardi.
;;;;  Reworked for CLOS November 1988, by Giuseppe Attardi.
;;;;  Updated May 2009, by Jean-Claude Beaudoin

(in-package "SYSTEM")

(export '(*break-readtable* *break-on-warnings* *break-enable*
	  *tpl-evalhook* *tpl-prompt-hook*))

(defvar *quit-tag* (cons nil nil))
(defvar *quit-tags* nil)
(defvar *break-level* 0)		; nesting level of error loops
(defvar *break-env* nil)
(defvar *ihs-base* 0)
(defvar *ihs-top* (ihs-top))
(defvar *ihs-current* 0)
(defvar *frs-base* 0)
(defvar *frs-top* 0)
(defvar *tpl-continuable* t)
(defvar *tpl-prompt-hook* nil)
(defvar *eof* (cons nil nil))

(defvar *last-error* nil)

(defvar *break-enable* t
  "ECL specific.
When an error is signaled, control enters a break loop only if the value of
this variable is non-NIL.  The initial value is T, but ECL automatically
rebinds this variable to NIL when control enters a break loop.")

(defvar *break-message* nil)

(defvar *break-readtable* nil)
(defvar *tpl-level* -1)			; nesting level of top-level loops
(defvar *step-level* 0)			; repeated from trace.lsp

(defvar *break-hidden-functions* '(error cerror apply funcall invoke-debugger))
(defvar *break-hidden-packages* (list #-ecl-min (find-package 'system)))

(defconstant tpl-commands
   '(("Top level commands"
      ((:cf :compile-file) tpl-compile-command :string
       ":cf		Compile file"
       ":compile-file &string &rest files		[Top level command]~@
	:cf &string &rest files				[Abbreviation]~@
	~@
	Compile files.  With no arguments, uses values from latest :cf~@
	command.  File extensions are optional.~%")
      ((:exit :eof) quit :eval
       ":exit or ^D	Exit Lisp"
       ":exit &eval &optional (status 0)		[Top level command]~@
	~@
	Exit Lisp without further confirmation.~%")
      ((:ld :load) tpl-load-command :string
       ":ld		Load file"
       ":load &string &rest files			[Top level command]~@
	:ld &string &rest files				[Abbreviation]~@
	~@
	Load files.  With no arguments, uses values from latest :ld~@
	or :cf command. File extensions are optional.~%")
      ((:step) tpl-step-command nil
       ":step		Single step form"
       ":step form					[Top level command]~@
	~@
	Evaluate form in single step mode.  While stepping, a new break~@
	level is invoked before every evaluation.  Extra commands are~@
	available at this time to control stepping and form evaluation.~%")
      ((:tr :trace) tpl-trace-command nil
       ":tr(ace)	Trace function"
       ":trace &rest functions				[Top level command]~@
	:tr &rest functions				[Abbreviation]~@
	~@
	Trace specified functions.  With no arguments, show currently~@
	traced functions.~@
	~@
	See also: :untrace.~%")
      ((:untr :untrace) tpl-untrace-command nil
       ":untr(ace)	Untrace function"
       ":untrace &rest functions			[Top level command]~@
	:untr &rest functions				[Abbreviation]~@
	~@
	Untrace specified functions.  With no arguments, untrace~@
	all functions.~@
	~@
	See also: :trace.~%")
      )
     ("Help commands"
      ((:apropos) tpl-apropos-command nil
       ":apropos	Apropos"
       ":apropos string &optional package		[Top level command]~@
	~@
	Finds all available symbols whose print names contain string.~@
	If a non NIL package is specified, only symbols in that package are considered.~@
	~%")
      ((:doc document) tpl-document-command nil
       ":doc(ument)	Document"
       ":document symbol				[Top level command]~@
	~@
	Displays documentation about function, print names contain string.~%")
      ((? :h :help) tpl-help-command nil
       ":h(elp) or ?	Help.  Type \":help help\" for more information"
       ":help &optional topic				[Top level command]~@
	:h &optional topic				[Abbrevation]~@
      	~@
	Print information on specified topic.  With no arguments, print~@
	quick summery of top level commands.~@
	~@
	Help information for top level commands follows the documentation~@
	style found in \"Common Lisp, the Language\"; and, in general, the~@
	commands themselves follow the conventions of Common Lisp functions,~@
	with the exception that arguments are normally not evaluated.~@
	Those commands that do evaluate their arguments are indicated by the~@
	keyword &eval in their description.  A third class of commands~@
	treat their arguments as whitespace-separated, case-sensitive~@
	strings, requiring double quotes only when necessary.  This style~@
	of argument processing is indicated by the keyword &string.~@
	For example, the :load command accepts a list of file names:
	~@
	:load &string &rest files			[Top level Command]~@
	~@
	whereas :exit, which requires an optional evaluated argument, is~@
	~@
	:exit &eval &optional status			[Top level Command]~%")
      )))

(defvar *tpl-commands* tpl-commands)

(defconstant break-commands
  '("Break commands"
     ((:q :quit) tpl-quit-command nil
       ":q(uit)		Return to some previous break level"
       ":quit &optional n				[Break command]~@
	:q &optional n					[Abbreviation]~@
	~@
	Without argument, return to top level;~@
	otherwise return to break level n.~%")
      ((:pop) (tpl-pop-command) :constant
       ":pop		Pop to previous break level"
       ":pop						[Break command]~@
	~@
	Pop to previous break level, or if already in top level,~@
	exit Lisp after confirmation.~%")
      ((:c :continue) continue nil
       ":c(ontinue)	Continue execution"
       ":continue					[Break command]~@
	:c						[Abbreviation]~@
	~@
	Continue execution.  Return from current break level to the caller.~@
	This command is only available when the break level is continuable~@
	(e.g., called from a correctable error or the function break).~%")
      ((:b :backtrace) tpl-backtrace nil
       ":b(acktrace)	Print backtrace"
       ":backtrace &optional n				[Break command]~@
	:b &optional n					[Abbreviation]~@
	~@
	Show function call history.  Only those functions called since~@
	the previous break level are shown.  In addition, functions compiled~@
	in-line or explicitly hidden are not displayed.  Without an argument,~@
	a concise backtrace is printed with the current function in upper~@
	case.  With integer argument n, the n functions above and including~@
	the current one are printed in a verbose format.~@
	~@
	See also: :function, :previous, :next.~%")
      ((:f :function) tpl-print-current nil
       ":f(unction)	Show current function"
       ":function					[Break command]~@
	:f						[Abbreviation]~@
	~@
	Show current function.  The current function is the implicit focus~@
	of attention for several other commands.  When it is an interpreted~@
 	function, its lexical environment is available for inspection and~@
	becomes the environment for evaluating user input forms.~@
	~@
	See also: :backtrace, :next, previous, :disassemble, :variables.~%")
      ((:p :previous) tpl-previous nil
       ":p(revious)	Go to previous function"
       ":previous &optional (n 1)			[Break command]~@
	:p &optional (n 1)				[Abbreviation]~@
	~@
	Move to the nth previous visible function in the backtrace.~@
 	It becomes the new current function.~@
	~@
	See also: :backtrace, :function, :go, :next.~%")
      ((:d :down) tpl-previous nil
       ":d(own)         Alias to :previous"
       ""
       )
      ((:n :next) tpl-next nil
       ":n(ext)		Go to next function"
       ":next &optional (n 1)				[Break command]~@
	:n &optional (n 1)				[Abbreviation]~@
	~@
	Move to the nth next visible function in the backtrace.  It becomes~@
	the new current function.~@
	~@
	See also: :backtrace, :function, :go, :previous.~%")
      ((:u :up) tpl-next nil
       ":u(p)           Alias to :next"
       ""
       )
      ((:g :go) tpl-go nil
       ":g(o)		Go to next function"
       ":go &optional (n 1)				[Break command]~@
	:g &optional (n 1)				[Abbreviation]~@
	~@
	Move to the function at IHS[i].~@
	See also: :backtrace, :function, :next, :previous.~%")
      ((:fs :forward-search) tpl-forward-search :string
       ":fs             Search forward for function"
       ":forward-search &string substring		[Break command]~@
	:fs &string substring				[Abbreviation]~@
	~@
	Search forward in the backtrace for function containing substring.~@
	The match is case insensitive.~@
	~@
	See also: :backtrace, :function, :next.~%")
      ((:bs :backward-search) tpl-backward-search :string
       ":bs             Search backward for function"
       ":backward-search &string substring		[Break command]~@
	:bs &string substring				[Abbreviation]~@
	~@
	Search backward in the backtrace for function containing substring.~@
	The match is case insensitive.~@
	~@
	See also: :backtrace, :function, :previous.~%")
      ((:disassemble) tpl-disassemble-command nil
       ":disassemble	Disassemble current function"
       ":disassemble					[Break command]~@
	:disassemble					[Abbreviation]~@
	~@
	Disassemble the current function. Currently, only interpreted functions~@
	can be disassembled.~%")
      ((:le :lambda-expression) tpl-lambda-expression-command nil
       ":l(ambda-)e(expression)	Show lisp code for current function"
       ":lambda-expression				[Break command]~@
	:le						[Abbreviation]~@
	~@
	Show the lisp code of the current function. Only works for interpreted~@
        functions.~%")
      ((:v :variables) tpl-variables-command nil
       ":v(ariables)	Show local variables, functions, blocks, and tags"
       ":variables &optional no-values			[Break command]~@
	:v &optional no-values				[Abbreviation]~@
	~@
	Show lexical variables, functions, block names, and tags local~@
	to the current function.  The current function must be interpreted.~@
	The values of local variables and functions are also shown,~@
	unless the argument is non-null.~%")
#|
      ((:l :local) tpl-local-command nil
       ":l(ocal)	Return the nth local value on the stack"
       ":local &optional (n 0)				[Break command]~@
	:l &optional (n 0)				[Abbreviation]
	~@
	For compiled functions, return the value of the nth lexical variable.~@
	As is done normally, the returned value is both printed by the top~@
	level as well as saved in the variable *.~%")
|#
      ((:hide) tpl-hide nil
       ":hide		Hide function"
       ":hide function					[Break command]~@
	~@
	Hide function.  A hidden function is not displayed in a backtrace.~@
	~@
	See also: :backtrace, :unhide, :hide-package.~%")
      ((:unhide) tpl-unhide nil
       ":unhide		Unhide function"
       ":unhide function				[Break command]~@
	~@
	Unhide function.  The specified function will be displayed in future~@
	backtraces, unless its home package is also hidden.~@
	~@
	See also: :backtrace, :hide, :unhide-package.~%")
      ((:hp :hide-package) tpl-hide-package nil
       ":hp		Hide package"
       ":hide-package package				[Break command]~@
	:hp package					[Abbreviation]~@
	~@
	Hide package.  Functions in a hidden package are not displayed~@
	in a backtrace.~@
	~@
	See also: :backtrace, :unhide-package.~%")
      ((:unhp :unhide-package) tpl-unhide-package nil
       ":unhp		Unhide package"
       ":unhide-package package				[Break command]~@
	:unhp package					[Abbreviation]~@
	~@
	Unhide package.  Functions in the specified package will be displayed~@
	in future backtraces, unless they are individually hidden.~@
	~@
	See also: :backtrace, :hide-package, :hide, :unhide.~%")
      ((:unhide-all) tpl-unhide-all nil
       ":unhide-all     Unhide all variables and packages"
       ":unhide-all					[Break command]~@
	~@
	Unhide all variables and packages.  All functions will be displayed~@
	in future backtraces.~@
	~@
	See also: :hide, :unhide, :hide-package, :unhide-package.~%")
#|
      ((:vs :value-stack) tpl-vs-command nil
       ":vs             Show value stack"
       ":value-stack &optional n			[Break command]~@
	:vs &optional n					[Abbreviation]~@
	~@
	Without an argument, show the entire value stack since the previous~@
	break level.  With an integer argument n, print nothing, but return~@
	the nth value stack entry.~@
	~@
	See also: :local.~%")
|#
      ((:bds :binding-stack) tpl-bds-command nil
       ":bds            Show binding stack"
       ":binding-stack &optional variable		[Break command]~@
	:bds &optional variable				[Abbreviation]~@
	~@
	Without an argument, show the entire binding stack since the previous~@
	break level.  With a variable name, print nothing, but return the~@
	value of the given variable on the binding stack.~%")
      ((:frs :frame-stack) tpl-frs-command nil
       ":frs            Show frame stack"
       ""
       )
      ((:m :message) tpl-print-message nil
       ":m(essage)      Show error message"
       ":message					[Break command]~@
	:m						[Abbreviation]~@
	~@
	Show current error message.~%")
      ((:hs :help-stack) tpl-help-stack-command nil
       ":hs		Help stack"
       ":help-stack					[Break command]~@
	:hs						[Abbrevation]~@
	~@
	Lists the functions to access the LISP system stacks.~%")
      ((:i :inspect) tpl-inspect-command nil
       ":i(nspect)      Inspect value of local variable"
       ":inspect var-name                               [Break command]~@
        :i var-name                                     [Abbreviation]~@
        ~@
        Inspect value of local variable named by var-name. Argument~@
        var-name can be a string or a symbol whose name string will~@
        then be used regardless of of the symbol's package.~@
        ~@
        See also: :variables.~%")
      #+threads
      ((:s :switch) tpl-switch-command nil
       ":s(witch)       Switch to next process to debug"
       ":switch debuggee                                [Break command]~@
        :s debuggee                                     [Abbreviation]~@
        ~@
        Switch to next process in need to debugger attention. Argument~@
        debuggee, when provided, must be an integer indicating the rank~@
        of the process in the debugger waiting list.~%")
      #+threads
      ((:w :waiting) tpl-waiting-command nil
       ":w(aiting)      Display debugger's waiting list"
       ":waiting                                        [Break command]~@
        :w                                              [Abbreviation]~@
        ~@
        Display debugger's waiting list.~%")
      )
  )

(defvar *lisp-initialized* nil)

(defun top-level ()
  "Args: ()
ECL specific.
The top-level loop of ECL. It is called by default when ECL is invoked."
  (catch *quit-tag*
    (let* ((*debugger-hook* nil)
	   + ++ +++ - * ** *** / // ///)

      (in-package "CL-USER")

      (unless *lisp-initialized*
	(let ((*break-enable* nil))
	  ;; process command arguments
	  (process-command-args))
	(format t "ECL (Embeddable Common-Lisp) ~A" (lisp-implementation-version))
	(format t "~%Copyright (C) 1984 Taiichi Yuasa and Masami Hagiya~@
Copyright (C) 1993 Giuseppe Attardi~@
Copyright (C) 2000 Juan J. Garcia-Ripoll
ECL is free software, and you are welcome to redistribute it~@
under certain conditions; see file 'Copyright' for details.")
	(format *standard-output* "~%Type :h for Help.  ")
	(setq *lisp-initialized* t))

      (let ((*break-enable* t)
	    (*tpl-level* -1))
	(tpl)))))

(defvar *allow-recursive-debug* nil)
(defvar *debug-status* nil)

(defun terminal-interrupt (correctablep)
  (let ((*break-enable* t))
    (if correctablep
      (cerror "Continues execution." 'ext:interactive-interrupt)
      (error "Console interrupt -- cannot continue."))))

(defun tpl (&key ((:commands *tpl-commands*) tpl-commands)
		 ((:prompt-hook *tpl-prompt-hook*) *tpl-prompt-hook*)
  		 (broken-at nil)
		 (quiet nil))
  (let* ((*ihs-base* *ihs-top*)
	 (*ihs-top* (if broken-at (ihs-search t broken-at) (ihs-top)))
	 (*ihs-current* (if broken-at (ihs-prev *ihs-top*) *ihs-top*))
	 (*frs-base* (or (sch-frs-base *frs-top* *ihs-base*) (1+ (frs-top))))
	 (*frs-top* (frs-top))
	 (*quit-tags* (cons *quit-tag* *quit-tags*))
	 (*quit-tag* *quit-tags*)	; any unique new value
	 (*tpl-level* (1+ *tpl-level*))
	 (break-level *break-level*)
	 values)
    (set-break-env)
    (set-current-ihs)
    (unless quiet
      (break-where))
    (flet ((rep ()
		(handler-bind 
		 ((condition
		   (lambda (condition)
		     (cond ((subtypep (type-of condition) 'warning)
			    ;; We let warnings pass by this way "warn" does the work.
			    )
			   ((< break-level 1)
			    ;; Toplevel should enter the debugger on any condition.
			    )
			   (*allow-recursive-debug*
			    ;; We are told to let the debugger handle this.
			    )
			   (t
			    (format t "~&Debugger received error: ~A~%~
                                         Error flushed.~%" condition)
			    (clear-input)
			    (return-from rep t) ;; go back into the debugger loop.
			    )
			   )
		     )))

		 (tpl-prompt)
		 (setq - (locally (declare (notinline tpl-read)) (tpl-read)))
		 (setq values
		       (multiple-value-list
			(eval-with-env - *break-env*)))
		 (setq /// // // / / values *** ** ** * * (car /))
		 (tpl-print values))))
	  (loop
	   (setq +++ ++ ++ + + -)
	   (when
	       (catch *quit-tag*
		 (if (zerop break-level)
		   (with-simple-restart 
                    (restart-toplevel "Go back to Top-Level REPL.")
                    (rep))
		   (with-simple-restart
		    (restart-debugger "Go back to debugger level ~D." break-level)
		    (rep)))
		 nil)
	     (break-where))))))

(defun tpl-prompt ()
  (typecase *tpl-prompt-hook*
    (string (format t *tpl-prompt-hook*))
    (function (funcall *tpl-prompt-hook*))
    (t (fresh-line)
       (format t "~A~V,,,'>A "
	       (if (eq *package* (find-package 'user))
		   ""
		 (package-name *package*))
	       (- *tpl-level* *step-level* -1)
	       ""))))

(defun tpl-read (&aux (*read-suppress* nil))
  (finish-output)
  (loop
    (case (peek-char nil *standard-input* nil :EOF)
      ((#\))
       (warn "Ignoring an unmatched right parenthesis.")
       (read-char))
      ((#\space #\tab)
       (read-char))
      ((#\newline #\return)
       (read-char)
       ;; avoid repeating prompt on successive empty lines:
       (let ((command (tpl-make-command :newline "")))
	 (when command (return command))))
      (:EOF
       (terpri)
       (return (tpl-make-command :EOF "")))
      (#\:
       (return (tpl-make-command (read-preserving-whitespace)
				 (read-line))))
      (#\?
       (read-char)
       (case (peek-char nil *standard-input* nil :EOF)
	 ((#\space #\tab #\newline #\return :EOF)
	  (return (tpl-make-command :HELP (read-line))))
	 (t
	  (unread-char #\?)
	  (return (read-preserving-whitespace)))))
      ;; We use READ-PRESERVING-WHITESPACE because with READ, if an
      ;; error happens within the reader, and we perform a ":C" or
      ;; (CONTINUE), the reader will wait for an inexistent #\Newline.
      (t
       (return (read))))))

(defvar *debug-tpl-commands* nil)

(defun harden-command (cmd-form)
  `(block 
    tpl-command
    (handler-bind 
     ((error (lambda (condition)
	       (unless *debug-tpl-commands*
		 (format t "~&Command aborted.~%Received condition: ~A" condition)
		 (clear-input)
		 (return-from tpl-command nil)
		 )
	       )
	     ))
     ,cmd-form
     )
    )
  )

(defun tpl-make-command (name line &aux (c nil))
  (dolist (commands *tpl-commands*)
    (when (setq c (assoc name (cdr commands) :test #'member))
      (return)))
  (cond ((null c)
	 (if (eq name :newline)		; special handling for Newline.
	     nil
	     `(tpl-unknown-command ',name)))
	((eq (third c) :restart)
	 `(progn
	    ;;(format t "~&About to invoke restart: ~A.~%" ,(second c))
	    (invoke-restart-interactively ,(second c))))
	((eq (third c) :eval)
	 `(,(second c) . ,(tpl-parse-forms line)))
	((eq (third c) :string)
	 (harden-command `(,(second c) . ,(tpl-parse-strings line))))
	((eq (third c) :constant)
	 (harden-command (second c)))
	(t
	 (harden-command `(,(second c) . ,(tpl-parse-forms line t))))))

(defun tpl-parse-forms (line &optional quote)
  (with-input-from-string (stream line)
    (do ((form (read stream nil *eof*) (read stream nil *eof*))
	 (list nil))
	((eq form *eof*) (nreverse list))
      (push (if quote `',form form) list))))

(defun tpl-parse-strings (line)
  (do ((i 0 end)
       (start)
       (end)
       (list nil)
       (space-p #'(lambda (c) (or (eql c #\space) (eql c #\tab))))
       (length (length line)))
      ((>= i length) (nreverse list))
    (cond ((null (setq start (position-if-not space-p line :START i)))
	   (setq end length))
	  ((eql (schar line start) #\")
	   (multiple-value-bind
	       (string n)
	       (read-from-string line t nil :START start)
	     (push string list)
	     (setq end n)))
	  (t
	   (setq end (or (position-if space-p line :START start) length))
	   (push (subseq line start end) list)))))

(defun tpl-print (values)
  (fresh-line)
  (dolist (v values)
    (prin1 v)
    (terpri)))

(defun tpl-unknown-command (command)
  (format t "Unknown top level command: ~s~%" command)
  (values))

(defun tpl-pop-command (&rest any)
  (declare (ignore any))
  (throw (pop *quit-tags*) t))

(defun tpl-quit-command (&optional (level 0))
  (when (and (>= level 0) (< level *tpl-level*))
    (let ((x (nth (- *tpl-level* level 1) *quit-tags*)))
      (throw x x)))
  (tpl-print-current))

(defun tpl-previous (&optional (n 1))
  (do ((i (si::ihs-prev *ihs-current*) (si::ihs-prev i)))
      ((or (< i *ihs-base*) (<= n 0)))
    (when (ihs-visible i)
      (setq *ihs-current* i)
      (decf n)))
  (set-break-env)
  (tpl-print-current))

(defun tpl-next (&optional (n 1))
  (do ((i (si::ihs-next *ihs-current*) (si::ihs-next i)))
      ((or (> i *ihs-top*) (<= n 0)))
    (when (ihs-visible i)
      (setq *ihs-current* i)
      (decf n)))
  (set-break-env)
  (tpl-print-current))

(defun tpl-go (ihs-index)
  (setq *ihs-current* (min (max ihs-index *ihs-base*) *ihs-top*))
  (if (ihs-visible *ihs-current*)
      (progn (set-break-env) (tpl-print-current))
      (tpl-previous)))

(defun tpl-print-message ()
  (when *break-message*
    (princ *break-message*)
    (terpri))
  (values))

(defun tpl-disassemble-command (&optional no-values)
  (let*((*print-level* 2)
	(*print-length* 4)
	(*print-pretty* t)
	(*print-readably* nil)
	(functions) (blocks) (variables))
    (unless (si::bc-disassemble (ihs-fun *ihs-current*))
      (tpl-print-current)
      (format t " Function cannot be disassembled.~%"))
    (values)))

(defun tpl-lambda-expression-command (&optional no-values)
  (let*(;;(*print-level* 2)
	;;(*print-length* 4)
	;;(*print-pretty* t)
	;;(*print-readably* nil)
	(function (ihs-fun *ihs-current*))
	(le (function-lambda-expression function)))
    (if le
	(pprint le)
	(format t " No source code available for this function.~%"))
    (values)))

(defun reconstruct-bytecodes-lambda-list (data)
  (declare (si::c-local data))
  (let ((output '()))
    (dotimes (n (pop data))	;; required values
      (declare (fixnum n))
      (push (pop data) output))
    (let ((l (pop data)))	;; optional values
      (declare (fixnum l))
      (unless (zerop l)
	(push '&optional output)
	(dotimes (n l)
	  (push (first data) output)
	  (setf data (cdddr data)))))
    (let ((rest (pop data)))	;; &rest value
      (when rest
	(push '&rest output)
	(push rest output)))
    (let* ((allow-other-keys (pop data))) ;; &keys and &allow-other-keys
      (unless (eql allow-other-keys 0)
	(push '&key output)
	(let ((l (pop data)))
	  (declare (fixnum l))
	  (dotimes (n l)
	    (let* ((key (first data))
		   (var (second data)))
	      (unless (and (keywordp key) (string= key var))
		(setf var (list (list key var))))
	      (push var output))))
	(when allow-other-keys
	  (push '&allow-other-keys output))))
    (nreverse output)))

(defun function-lambda-list (function)
  (cond
    ((typep function 'generic-function)
     (generic-function-lambda-list function))
    ((not (typep function 'compiled-function))
     (function-lambda-list (fdefinition function)))
    ;; Use the lambda list from the function definition, if available,
    ;; but remove &aux arguments.
    ((let ((f (function-lambda-expression function)))
       (when f
	 (let* ((list (if (eql (first f) 'LAMBDA)
			  (second f)
			  (third f)))
		(ndx (position '&aux list)))
	   (if ndx
	       (subseq list 0 (1- ndx))
	       list)))))
    ;; Reconstruct the lambda list from the bytecodes
    ((multiple-value-bind (lex-env bytecodes data)
	 (si::bc-split function)
       (when bytecodes
	 (reconstruct-bytecodes-lambda-list (coerce data 'list)))))))

#-ecl-min
(defun decode-env-elt (env ndx)
  (ffi:c-inline (env ndx) (:object :fixnum) :object
                "
	cl_object v = #0;
	cl_index ndx = #1;
	typedef struct ecl_var_debug_info *pinfo;
	pinfo d = (pinfo)(v->vector.self.t[1]) + ndx;
	cl_object name = make_constant_base_string(d->name);
	void *value = (void*)(v->vector.self.t[2+ndx]);
	cl_object output;
	switch (d->type) {
	case _ecl_object_loc:
		output = *((cl_object*)value);
		break;
	case _ecl_fixnum_loc: {
		cl_fixnum *p = (cl_fixnum*)value;
		output = ecl_make_integer(*p);
		break;
	}
	case _ecl_float_loc: {
		float *p = (float*)value;
		output = ecl_make_singlefloat(*p);
		break;
	}
	case _ecl_double_loc: {
		float *p = (double*)value;
		output = ecl_make_doublefloat(*p);
		break;
	}
	default: {
		ecl_base_char *p = (ecl_base_char*)value;
		output = CODE_CHAR(*p);
		break;
	}
	}
	@(return) = CONS(name,output);
" :one-liner nil))

(defun decode-ihs-env (*break-env*)
  (let ((env *break-env*))
    (if (vectorp env)
      #+ecl-min
      nil
      #-ecl-min
      (let* ((next (decode-ihs-env
                    (ffi:c-inline (env) (:object) :object
                                  "(#0)->vector.self.t[0]" :one-liner t))))
        (nreconc (loop with l = (- (length env) 2)
                       for i from 0 below l
                       do (push (decode-env-elt env i) next))
                   next))
      env)))

(defun tpl-variables-command (&optional no-values)
  (let*((*print-level* 2)
	(*print-length* 4)
	(*print-pretty* t)
	(*print-readably* nil)
	(functions '())
	(blocks '())
	(variables '())
	record0 record1)
    (dolist (record (decode-ihs-env *break-env*))
      (cond ((atom record)
	     (push (compiled-function-name record) functions))
	    ((progn
	       (setf record0 (car record) record1 (cdr record))
	       (or (symbolp record0) (stringp record0)))
	     (setq variables (list* record0 record1 variables)))
	    ((symbolp record1)
	     (push record1 blocks))
	    (t
	     )))
    (format t "~:[~;Local functions: ~:*~{~s~^, ~}.~%~]" functions)
    (format t "~:[~;Block names: ~:*~{~s~^, ~}.~%~]" blocks)

    ;; This format is the what was in the orignal code.
    ;; It simply does not work when no-values is t.
    ;; If you care to debug this kind of conundrum then have fun!
    ;;(format t "Local variables: ~:[~:[none~;~:*~{~a~1*~:@{, ~a~1*~}~}~]~;~
    ;;                            ~:[none~;~:*~{~%  ~a: ~s~}~]~]~%"
    ;;          (not no-values) variables)
    (format t "Local variables: ")
    (if variables
	(if no-values
	    (do ((vals variables (cddr vals)))
		((endp vals))
		(format t "~%  ~A" (car vals))
		)
	  (do ((vals variables (cddr vals)))
	      ((endp vals))
	      (format t "~%  ~A: ~S" (car vals) (cadr vals))
	   )
	  )
      (format t "none")
      )
    (terpri)
    (values)))

(defun tpl-inspect-command (var-name)
  (when (symbolp var-name)
    (setq var-name (symbol-name var-name)))
  (let ((val-pair (assoc var-name (decode-ihs-env *break-env*)
			 :test #'(lambda (s1 s2)
				   (when (symbolp s2) (setq s2 (symbol-name s2)))
				   (if (stringp s2)
				       (string-equal s1 s2)
				     nil)))))
    (when val-pair
      (format t "~&In tpl-inspect-command: val-pair = ~S~%" val-pair)
      (let ((val (cdr val-pair)))
	(inspect val)))))

(defun tpl-bds-command (&optional var)
  (if var
    (do ((bi (1+ (frs-bds (max 0 (1- *frs-base*)))) (1+ bi))
	 (last (frs-bds (1+ *frs-top*))))
	((> bi last)
	 (format t "Variable not found.~%")
	 (values))
      (when (eq (bds-var bi) var)
	(return (let ((val (bds-val bi)))
		  (if (unbound-value-p val) "<unbound value>" val)))))
    (do ((bi (1+ (frs-bds (max 0 (1- *frs-base*)))) (1+ bi))
	 (last (frs-bds (1+ *frs-top*)))
	 (fi *frs-base*)
	 (*print-level* 2)
	 (*print-length* 4)
	 (*print-pretty* t))
	((> bi last) (values))
      (do ()
	  ((or (> fi *frs-top*) (>= (frs-bds fi) bi)))
	(print-frs fi)
	(incf fi))
      (format t "BDS[~d]: ~s = ~s~%"
	      bi (bds-var bi)
	      (let ((val (bds-val bi)))
		(if (unbound-value-p val) "<unbound value>" val))))))

(defun tpl-backtrace (&optional n)
  (let ((*print-pretty* nil)	 ;; because CLOS allows (setf foo) as function names
	(base *ihs-base*)
	(top *ihs-top*))
    (format t "~&Backtrace:~%")
    (if (null n)
	(do ((i top (si::ihs-prev i))
	     ;;(b nil t)
	     )
	    ((< i base))
	    (when (ihs-visible i)
	      (let ((*print-case* (if (= i *ihs-current*) :UPCASE :DOWNCASE))
		    (func-name (ihs-fname i)))
		;;(format t "~:[~; >~] ~S" b (ihs-fname i)) ;; JCB
		(format t "  > ~S" func-name)
		(when (eq func-name 'si::bytecodes)
		  (format t " [Evaluation of: ~S]"
                          (function-lambda-expression (ihs-fun i))))
		(terpri)
		)))
      (progn
	(if (eq t n)
	    (setq base 0)
	  (progn
	    (unless (integerp n)
	      (error "Argument to command :backtrace must be an integer or t."))
	    (setq top *ihs-current*)
	    )
	  )
	(do ((i top (si::ihs-prev i))
	     ;;(b nil t)
	     (j 0 (1+ j))
	     (max (if (eq t n) *ihs-top* n))
	     )
	    ((or (< i base) (>= j max))
	     (when (zerop i) (format t "  > ---end-of-stack---~%"))
	     )
	    (when (or (ihs-visible i) (eq t n))
	      (let ((*print-case* (if (= i *ihs-current*) :UPCASE :DOWNCASE))
		    (func-name (ihs-fname i)))
		;;(format t "~:[~; >~] ~S" b (ihs-fname i)) ;; JCB
		(format t "  > ~S" (ihs-fname i))
		(when (eq func-name 'si::bytecodes)
		  (format t " [Evaluation of: ~S]" (function-lambda-expression (ihs-fun i))))
		(terpri)
		))))
      )
    (terpri))
  (values))

(defun tpl-frs-command (&optional n)
  (unless n (setq n *ihs-top*))
  (unless (integerp n)
    (error "Argument to command :frs must be an integer."))
  (do ((i *ihs-top* (si::ihs-prev i))
       (k n (1- k)))
      ((= k 0) (values))
      (let*((j (or (sch-frs-base *frs-base* i) (1+ *frs-top*)))
	    (*print-level* 2)
	    (*print-length* 4)
	    (*print-pretty* t))
	(do () ((or (> j *frs-top*) (> (frs-ihs j) i)))
	    (print-frs j)
	    (incf j)))))

(defun print-frs (i)
  (format *debug-io* "    FRS[~d]: ---> IHS[~d],BDS[~d]~%"
	  i (frs-ihs i) (frs-bds i)))

(defun break-where ()
  (if (<= *tpl-level* 0)
      #-threads (format t "~&Top level.~%")
      #+threads (format t "~&Top level in: ~S.~%" mp:*current-process*)
    (tpl-print-current)))

(defun tpl-print-current ()
  (let ((name (ihs-fname *ihs-current*)))
    (format t "~&Broken at ~:@(~S~)." name)
    (when (eq name 'si::bytecodes)
      (format t " [Evaluation of: ~S]"
              (function-lambda-expression (ihs-fun *ihs-current*)))))
  #-threads (terpri)
  #+threads (format t " In: ~S.~%" mp:*current-process*)
  (let ((fun (ihs-fun *ihs-current*)))
    (when (and (symbolp fun) (fboundp fun))
      (setf fun (fdefinition fun)))
    (multiple-value-bind (file position)
	(ext:compiled-function-file fun)
      (when file
	(format t " File: ~S (Position #~D)~%" file position))))
  (values))

(defun tpl-hide (fname)
  (unless (member fname *break-hidden-functions* :test #'eq)
    (push fname *break-hidden-functions*)
    (unless (ihs-visible *ihs-current*)
      (set-current-ihs)))
  (values))

(defun tpl-unhide (fname)
  (setq *break-hidden-functions*
	(delete fname *break-hidden-functions* :test #'eq))
  (values))

(defun tpl-unhide-package (package)
  (setq *break-hidden-packages*
	(delete (find-package package) *break-hidden-packages* :test #'eq))
  (values))

(defun tpl-unhide-all ()
  (setq *break-hidden-functions* nil)
  (setq *break-hidden-packages* nil)
  (values))

(defun tpl-hide-package (package)
  (setq package (find-package package))
  (unless (member package *break-hidden-packages* :test #'eq)
    (push package *break-hidden-packages*)
    (unless (ihs-visible *ihs-current*)
      (set-current-ihs)))
  (values))

(defun ihs-visible (i)
  (let ((fname (ihs-fname i)))
    #+clos
    (when (and (consp fname) (eq 'SETF (car fname)))
	  (setq fname (second fname)))
    (or (eq fname 'EVAL)
	(eq fname 'BYTECODES)
	(and (not (member (symbol-package fname) *break-hidden-packages*
			  :TEST #'eq))
	     (not (null fname))
	     (not (member fname *break-hidden-functions* :TEST #'eq))))))

(defun ihs-fname (i)
  (let ((function (ihs-fun i)))
    (cond ((symbolp function) function)
          ((compiled-function-p function)
           (or (compiled-function-name function) 'lambda))
	  #+clos
	  ((si:instancep function) (slot-value function 'name))
          (t :zombi))))

(defun set-current-ihs ()
  (do ((i *ihs-current* (si::ihs-prev i)))
      ((or (and (ihs-visible i) (setq *ihs-current* i))
	   (<= i *ihs-base*))))
  (set-break-env))

(defun set-break-env ()
  (setq *break-env* (ihs-env *ihs-current*)))

(defun ihs-search (string unrestricted &optional (start (si::ihs-top)))
  (do ((ihs start (si::ihs-prev ihs)))
      ((< ihs *ihs-base*)
       (return nil))
    (when (and (or unrestricted (ihs-visible ihs))
	       (search (string string) (symbol-name (ihs-fname ihs))
		       :test #'char-equal))
      (return ihs))))

(defun tpl-backward-search (string)
  (let ((new-ihs (ihs-search string nil *ihs-current*)))
    (cond (new-ihs
	   (setf *ihs-current* new-ihs)
	   (set-current-ihs)
	   (tpl-print-current))
	  (t
	   (format *debug-io* "Search for ~a failed.~%" string)))
    (values)))

(defun tpl-forward-search (string)
  (do ((ihs (si::ihs-next *ihs-current*) (si::ihs-next ihs)))
      ((> ihs *ihs-top*)
       (format *debug-io* "Search for ~a failed.~%" string))
    (when (and (ihs-visible ihs)
	       (search string (symbol-name (ihs-fname ihs))
		       :test #'char-equal))
      (setq *ihs-current* ihs)
      (set-current-ihs)
      (tpl-print-current)
      (return)))
  (values))

(defun tpl-apropos-command (&optional string pkg)
  (when string (apropos string pkg)))

(defun tpl-document-command (&optional symbol)
  (when symbol (help symbol)))

(defun tpl-step-command (&optional form)
  (when form (step* form)))

(defun tpl-trace-command (&rest functions)
  (trace* functions))

(defun tpl-untrace-command (&rest functions)
  (untrace* functions))

(defvar *tpl-last-load* nil)

(defun tpl-load-command (&rest files)
  (when files
    (setq *tpl-last-load* files))
  (dolist (file *tpl-last-load*) (load file))
  *tpl-last-load*)

(defvar *tpl-last-compile* nil)

(defun tpl-compile-command (&rest files)
  (when files
    (setq *tpl-last-compile* files))
  (dolist (file *tpl-last-compile*) (compile-file file))
  (setq *tpl-last-load* *tpl-last-compile*))

(defun tpl-help-command (&optional topic)
  (cond ((null topic)
	 (dolist (commands *tpl-commands*)
	   (format t "~%~A:~%" (car commands))
	   (dolist (c (cdr commands))
	     (when (fourth c)
	       (format t "~A.~%" (fourth c))))))
	((or (stringp topic) (symbolp topic))
	 (let (c)
	   (setq topic (intern (string topic) (find-package 'keyword)))
	   (dolist (commands *tpl-commands*)
	     (when (setq c (assoc topic (cdr commands) :test #'member))
	       (return)))
	   (cond ((null (fifth c))
		  (format t "No such help topic: ~s~%"
			  (string topic)))
		 (t
		  (terpri)
		  (format t (fifth c))
		  (terpri)))))
	(t
	 (format t "Not a valid help topic: ~s~%" topic)))
  (values))

(defun tpl-help-stack-command ()
  (format t "
Use the following functions to directly access ECL stacks.

Invocation History Stack:
(sys:IHS-TOP)	Returns the index of the TOP of the IHS.
(SYS:IHS-FUN i)	Returns the function of the i-th entity in IHS.
(SYS:IHS-ENV i)
(SYS:IHS-PREV i)
(SYS:IHS-NEXT i)

Frame (catch, block) Stack:
(sys:FRS-TOP)	Returns the index of the TOP of the FRS.
(SYS:FRS-BDS i)	Returns the BDS index of the i-th entity in FRS.
(SYS:FRS-IHS i)	Returns the IHS index of the i-th entity in FRS.
(SYS:FRS-TAG i)

Binding Stack:
(sys:BDS-TOP)	Returns the index of the TOP of the BDS.
(SYS:BDS-VAR i)	Returns the symbol of the i-th entity in BDS.
(SYS:BDS-VAL i)	Returns the value of the i-th entity in BDS.

Note that these functions are named by external symbols in the SYSTEM
package."
))

(defun compute-restart-commands (condition &key display)
  (let ((restarts (compute-restarts condition))
	(restart-commands (list "Restart commands")))
    (when display
      (format display (if restarts
			  "~&Available restarts:~2%" 
			  "~&No restarts available.~%")))
    (loop for restart in restarts
       and i from 1
       do (let ((user-command (format nil "r~D" i))
		(name (format nil "~@[(~A)~]" (restart-name restart)))
		(helpstring (princ-to-string restart)))
	    (push (list
		   (list (intern (string-upcase user-command) :keyword))
		   restart :restart
		   (format nil ":~A~16T~A~24T~A" user-command helpstring name)
		   (format nil ":~A~48T~A~& ~&~A~A" (string-downcase user-command)
                           "[Restart command]" name helpstring))
		  restart-commands)
	    (when display
	      (format display "~D. ~A ~A~%" i name restart))))
    (when display (terpri display))
    (nreverse restart-commands)))

(defun update-debug-commands (restart-commands)
  (let ((commands (copy-list *tpl-commands*)))
    (unless (member break-commands commands)
      (setq commands (nconc commands (list break-commands)))
      )
    (delete-if
     #'(lambda (x) (string= "Restart commands" (car x)))
     commands)
    (nconc commands (list restart-commands))))

(defvar *default-debugger-maximum-depth* 16)

(defun check-default-debugger-runaway ()
  (when (< *default-debugger-maximum-depth* *break-level*)
    #+threads 
    (progn
      (format *error-output*
	      "~&Excessive debugger depth! Probable infinite recursion!~%~
             Quitting process: ~S.~%" mp:*current-process*)
      (when (< (+ *default-debugger-maximum-depth* 3) *break-level*)
	;; we tried to be polite but it does not seem to work.
	(quit -1))
      (exit-process))
    #-threads 
    (progn
      (format *error-output*
	    "~&Excessive debugger depth! Probable infinite recursion!~%~
             Quitting.~%")
        (quit -1))))

#+threads
(progn
  (defvar *debugger-waiting-list-lock* (mp:make-lock :name 'debugger-waiting-list))
  (defvar *debugger-waiting-list* nil)
  (defvar *debugger-lock* (mp:make-lock :name 'debugger))
  (defvar *debuggee-elect* nil)
  (defvar *debuggee* nil)
  )

#+threads
(defun tpl-switch-command (&optional rank)
  (when (integerp rank)
    (let ((max (list-length *debugger-waiting-list*)))
      (unless (and (< 0 rank) (<= rank max))
	(error "Debugger switch command: Invalid argument value.")))
    (let ((elect (car (last *debugger-waiting-list* rank))))
      (when elect
	(setq *debuggee-elect* elect))))
  (invoke-restart 'suspend-debug)
  (values))

#+threads
(defun tpl-waiting-command ()
  (labels ((display-waitee (waiting-list)
	     (unless waiting-list
	       (return-from display-waitee 0))
	     (let ((rank (1+ (display-waitee (cdr waiting-list)))))
	       (format t "    ~D: ~s~%" rank (car waiting-list))
	       rank)))
    (format t "~&~%Debugger's waiting list:~2%")
    (display-waitee *debugger-waiting-list*)
    (terpri))
  (values))

#+threads
(defun register-on-debugger-waiting-list (process)
  (mp:with-lock
   (*debugger-waiting-list-lock*)
   (unless (find process *debugger-waiting-list*)
     (push process *debugger-waiting-list*)
     (format *error-output* "~&~2%Debugger called in: ~S.~2%" process)
     (finish-output))))

#+threads
(defun remove-from-debugger-waiting-list (process)
  (mp:with-lock
   (*debugger-waiting-list-lock*)
   (setq *debugger-waiting-list* (delete process *debugger-waiting-list*))))

#+threads
(defmacro with-debugger-lock (&body body)
  `(mp:with-lock (*debugger-lock*)
		 ,@body))

#-threads
(defmacro with-debugger-lock (&body body)
  `(progn ,@body))

(defun default-debugger (condition)
  (unless *break-enable*
    (throw *quit-tag* nil))
  (let*((*standard-input* *debug-io*)
	(*standard-output* *debug-io*)
	;;(*tpl-prompt-hook* "[dbg] ")
	(*print-pretty* nil)
	(*print-circle* t)
	(*readtable* (or *break-readtable* *readtable*))
	(*break-message* (format nil "~&~A~%" condition))
	(*break-level* (1+ *break-level*))
	(break-level *break-level*)
	(*break-env* nil))
    (check-default-debugger-runaway)
    (tagbody
     ;;debug
     waiting-room
     #+threads (register-on-debugger-waiting-list mp:*current-process*)
     (with-debugger-lock
      #+threads 
      (progn
	(when *debuggee-elect*
	  (unless (eq *debuggee-elect* mp:*current-process*)
	    (when (find *debuggee-elect* *debugger-waiting-list*)
	      (when (mp:process-active-p *debuggee-elect*)
		;; if *debuggee-elect* is dead we just pick-up the first comer.
		(go waiting-room))))
	  )
	(setq *debuggee* mp:*current-process* *debuggee-elect* nil)
	(remove-from-debugger-waiting-list mp:*current-process*))
      (when (listen *debug-io*)
	(clear-input *debug-io*))
      ;; Like in SBCL, the error message is output through *error-output*
      ;; The rest of the interaction is performed through *debug-io*
      (finish-output)
      (fresh-line *error-output*)
      (terpri *error-output*)
      (princ *break-message* *error-output*)
      ;; Here we show a list of restarts and invoke the toplevel with
      ;; an extended set of commands which includes invoking the associated
      ;; restarts.
      (restart-case
       (let* ((restart-commands (compute-restart-commands condition :display t))
	      (debug-commands 
	       ;;(adjoin restart-commands (adjoin break-commands *tpl-commands*))
	       (update-debug-commands restart-commands)
	       ))
	 (tpl :commands debug-commands)
	 )
       #+threads
       (suspend-debug ()
	 :report (lambda (s)
		   (format s "Put this process back on debugger's waiting list."))
	 (go waiting-room))
       (quit-debugger ()
	 :report (lambda (s)
		   (format s "Quit debugger level ~D." break-level))
	 (go quit)))
      ) ; with-debugger-lock
     quit
     ;; (format *debug-io* "~&Leaving debugger level ~D.~%" break-level)
     ;; As of ECL 9.4.1 making a normal function return from the debugger
     ;; seems to be a very bad idea! Basically, it dumps core...
     (throw *quit-tag* t)
     ) ; tagbody
    ))

(defun invoke-debugger (condition)
  (when *debugger-hook*
    (let* ((old-hook *debugger-hook*)
	   (*debugger-hook* nil))
      (funcall old-hook condition old-hook)))
  (locally 
    (declare (notinline default-debugger))
    (if (<= 0 *tpl-level*) ;; Do we have a top-level REPL above us?
        (default-debugger condition)
        (let* (;; We do not have a si::top-level invocation above us
               ;; so we have to provide the environment for interactive use.
               (*break-enable* *break-enable*)
               (*debugger-hook* *debugger-hook*)
               (*quit-tags* (cons *quit-tag* *quit-tags*))
               (*quit-tag* *quit-tags*)	; any unique new value
               (*ihs-top* 0) ;; Or should it be 1?
               (*tpl-level* (1+ *tpl-level*)) ;; Or should we simply say 0.
               (*tpl-commands* *tpl-commands*)
               + ++ +++ - * ** *** / // ///)
          (catch *quit-tag*
            (default-debugger condition)))))
  (finish-output))

(defun safe-eval (form env err-value)
  (catch 'si::protect-tag
    (let* ((*debugger-hook*
	    #'(lambda (condition old-hooks)
		(throw 'si::protect-tag condition))))
      (return-from safe-eval (eval-with-env form env))))
  err-value)

#-ecl-min
(package-lock "COMMON-LISP" t)
