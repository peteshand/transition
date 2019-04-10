package transition;

import haxe.Timer;
import notifier.Notifier;
//import condition.IState;
import condition.Condition;
import motion.Actuate;
import motion.actuators.GenericActuator;
import motion.easing.Linear.LinearEaseNone;
import motion.easing.Linear;
import signal.Signal;

/**
 * ...
 * @author P.J.Shand
 */
class Transition
{
	static var tweenCountReg = new Map<Transition, Bool>();
	static var linearEaseNone:LinearEaseNone;
	
	public static var globalTweenCount = new Notifier<Int>(0);
	public static var globalTransitioning = new Notifier<Bool>(false);
	
	public static inline var SHOW:String = "show";
	public static inline var HIDE:String = "hide";

	var transitionObjects = new Array<TransitionObject>();
	var queuedFunction:Void->Void;
	
	var transitioningIn = new Notifier<Bool>(false);
	var transitioningOut = new Notifier<Bool>(false);
	var progress:Notifier<Null<Float>>;
	var target:Dynamic;
	var tween:GenericActuator<Transition>;
	var showDelayTimer:Timer;
	var hideDelayTimer:Timer;

	////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////////
	public var onShowStart = new Signal();														////
	public var onShowUpdate = new Signal();														////
	public var onShowComplete = new Signal();													////
																								////
	public var onHideStart = new Signal();														////
	public var onHideUpdate = new Signal();														////
	public var onHideComplete = new Signal();													////
	////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////////

	public var showTime:Float = 1;
	public var showDelay:Float = 0;
	
	public var hideTime:Float = 1;
	public var hideDelay:Float = 0;
	
	public var showing:Null<Bool>;
	public var isTweening = new Notifier<Bool>(false);
	public var totalTransTime(get, null):Float;
	
	public var sceneTransition:Bool = false;
	public var queueTransitions:Bool = true;
	public var startHidden:Bool = true;

	@:isVar public var value(get, set):Float = 0;
	//@:isVar public var state(default, set):IState;
	@:isVar public var condition(default, set):Condition;
	
	public function new(?showTime:Float = 1, ?hideTime:Float = 1, ?showDelay:Float = 0, ?hideDelay:Float = 0, ?startHidden:Bool = true, ?condition:Condition) 
	{
		this.showTime = showTime;
		this.hideTime = hideTime;
		this.showDelay = showDelay;
		this.hideDelay = hideDelay;
		this.startHidden = startHidden;
		
		
		if (linearEaseNone == null) linearEaseNone = new LinearEaseNone();
		//onShowUpdate.add(ActivityModel.animating);
		//onHideUpdate.add(ActivityModel.animating);
		
		globalTweenCount.add(onTweenCountChange);
		isTweening.add(onIsTweeningChange);
		
		progress = new Notifier<Null<Float>>(0);
		progress.add(onProgressChange);
		if (startHidden) progress.value = -1;
		else progress.value = 0;

		this.condition = condition;
	}
	
	function onProgressChange() 
	{
		if (value == 0) this.showing = true;
		else if (value <= -1 || value >= 1) {
			this.showing = false;
			
		}
		
		if (value < -1) value = -1;
		else if (value > 1) value = 1;
		
		if (transitionObjects == null) {
			throw "this transition object has been disposed and should not be referenced";
		}
		for (i in 0...transitionObjects.length)
		{	
			transitionObjects[i].update(value);
		}
	}
	
	function onIsTweeningChange() 
	{
		if (sceneTransition) {
			if (isTweening.value) {
				tweenCountReg.set(this, true);
				globalTweenCount.value = countReg(tweenCountReg);
			}
			else {
				tweenCountReg.remove(this);
				globalTweenCount.value = countReg(tweenCountReg);
			}
		}
	}
	
	function onTweenCountChange() 
	{
		if (globalTweenCount.value == 0) globalTransitioning.value = false;
		else globalTransitioning.value = true;
	}
	
	// --------------------------------------------------- //
	/* @param target Target object whose properties this tween affects. 
	*  @param tweenObject, dynamic object containing properties to tweet, with a [hide, show] value, or [hide, show, hide] value. 
	*  @param options, TransitionSettings typedef object containing tween options. Options are as follows: 
	* "ease", "showEase", "hideEase", "autoVisible", "autoVisObject", "start", "end", "startHidden",
	*  @return Void */
	
	public function add(target:Dynamic, properties:Dynamic=null, options:TransitionSettings=null):ITransitionObject 
	{
		this.target = target;
		
		if (!target) throw "target must not be null";
		var transitionObject = getTransitionObject(target);
		transitionObject.set(properties, options);
		transitionObject.update(value);
		
		return transitionObject;
	}
	
	public function remove(target:Dynamic, vars:Dynamic=null):Void 
	{
		if (vars != null) {
			getTransitionObject(target).remove(vars);
		}
		else {
			for (transitionObject in transitionObjects) 
			{
				if (transitionObject.target == target) {
					transitionObject.dispose();
					transitionObjects.remove(transitionObject);
				}
			}
		}
	}
	
	function getTransitionObject(target:Dynamic):TransitionObject 
	{
		var transitionObject = new TransitionObject(target);
		transitionObject.target = target;
		transitionObjects.push(transitionObject);
		return transitionObject;
	}
	
	function queue(func:Void->Void):Void 
	{
		queuedFunction = func;
	}
	
	// --------------------------------------------------- //
	public function stop(value:Float)
	{
		killDelays();
		stopCurrentTween();
		this.value = value;
	}

	public function Show():Void
	{
		if (isTweening.value && queueTransitions) {
			queue(Show);
			return;
		}
		
		if (showing == true) return;
		if (showing == null) {
			showJump();
			showing = true;
			return;
		}
		
		if(progress.value == 1) {
			this.value = -1;
		}
		killDelays();
		isTweening.value = true;
		if (showTime == 0) {
			if (showDelay == 0) showJump();
			else {
				showDelayTimer = Timer.delay(showJump, Math.floor(showDelay * 1000));
			}
		}
		else {
			if (showDelay == 0) showTween();
			else {
				showDelayTimer = Timer.delay(showTween, Math.floor(showDelay * 1000));
			}
		}
	}
	
	function killDelays() 
	{
		if (showDelayTimer != null){
			showDelayTimer.stop();
			showDelayTimer = null;
		}
		if (hideDelayTimer != null){
			hideDelayTimer.stop();
			hideDelayTimer = null;
		}
	}
	
	function showTween():Void 
	{
		stopCurrentTween();
		tween = Actuate.tween(this, showTime, { value:0 } ).onUpdate(privateShowOnUpdate).onComplete(privateShowOnComplete).ease(linearEaseNone);
		privateShowOnStart();
	}
	
	function showJump():Void 
	{
		progress.value = 0;
		privateShowOnStart();
		privateShowOnUpdate();
		privateShowOnComplete();
	}
	
	public function Hide():Void
	{
		if (isTweening.value && queueTransitions) {
			queue(Hide);
			return;
		}
		if (showing == false) return;
		if (showing == null) {
			hideJump();
			showing = false;
			return;
		}
		showing = false;
		
		killDelays();
		isTweening.value = true;
		if (hideTime == 0) {
			if (hideDelay == 0) hideJump();
			else {
				hideDelayTimer = Timer.delay(hideJump, Math.floor(hideDelay * 1000));
			}
		}
		else {
			if (hideDelay == 0) hideTween();
			else {
				hideDelayTimer = Timer.delay(hideTween, Math.floor(hideDelay * 1000));
			}
		}
	}
	
	public function dispose() 
	{
		if (transitionObjects == null) return;
		
		Actuate.stop(this);
		
		var i:Int = transitionObjects.length - 1;
		while (i >= 0) 
		{
			transitionObjects[i].dispose();
			transitionObjects.splice(i, 1);
			i--;
		}
		queuedFunction = null;
		progress.remove();
		onShowStart.remove();
		onShowUpdate.remove();
		onShowComplete.remove();
		onHideStart.remove();
		onHideUpdate.remove();
		onHideComplete.remove();
		target = null;
		
		if (tween != null) Actuate.unload(tween);
		
		tween = null;
	}
	
	function hideTween():Void
	{
		stopCurrentTween();
		tween = Actuate.tween(this, hideTime, { value:1 } ).onUpdate(privateHideOnUpdate).onComplete(privateHideOnComplete).ease(linearEaseNone);
		privateHideOnStart();
	}

	function stopCurrentTween()
	{
		Actuate.stop(this);
		if (tween != null){
			Actuate.unload(tween);
		}
	}
	
	function hideJump():Void 
	{
		progress.value = 1;
		privateHideOnStart();
		privateHideOnUpdate();
		privateHideOnComplete();
	}
	
	// --------------------------------------------------- //
	
	function privateShowOnStart():Void 
	{
		showing = true;
		transitioningIn.value = true;
		for (i in 0...transitionObjects.length) transitionObjects[i].showBegin();
		onShowStart.dispatch();
	}
	
	function privateShowOnUpdate():Void 
	{
		onShowUpdate.dispatch();
	}
	
	function privateShowOnComplete():Void 
	{
		isTweening.value = false;
		transitioningIn.value = false;
		for (i in 0...transitionObjects.length) transitionObjects[i].showEnd();
		onShowComplete.dispatch();
		checkQueue();
	}
	
	// --------------------------------------------------- //
	
	function privateHideOnStart():Void 
	{
		transitioningOut.value = true;
		for (i in 0...transitionObjects.length) transitionObjects[i].hideBegin();
		onHideStart.dispatch();
	}
	
	function privateHideOnUpdate():Void 
	{
		onHideUpdate.dispatch();
	}
	
	function privateHideOnComplete():Void 
	{
		isTweening.value = false;
		transitioningOut.value = false;
		for (i in 0...transitionObjects.length) transitionObjects[i].hideEnd();
		onHideComplete.dispatch();
		checkQueue();
	}
	
	function countReg(tweenCountReg:Map<Transition, Bool>):Int
	{
		var count:Int = 0;
		for (key in tweenCountReg.keys()) 
		{
			count++;
		}
		return count;
	}
	
	function checkQueue():Void 
	{
		if (queuedFunction != null) {
			queuedFunction();
			queuedFunction = null;
		}
	}
	
	function get_totalTransTime():Float 
	{
		return showDelay + showTime + hideDelay + hideTime;
	}
	
	function get_value():Float 
	{
		return progress.value;
	}
	
	function set_value(value:Float):Float 
	{
		return progress.value = value;
	}

	function set_condition(value:Condition):Condition
	{
		if (condition != null){
			condition.onActive.remove(Show);
			condition.onInactive.remove(Hide);
		}
		condition = value;
		if (condition != null){
			condition.onActive.add(Show);
			condition.onInactive.add(Hide);
			if (condition.value) Show();
			else Hide();
		}
		return condition;
	}
}
