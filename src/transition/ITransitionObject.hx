package transition;

import motion.easing.IEasing;

/**
 * @author P.J.Shand
 */
interface ITransitionObject {
	function showEase(ease:IEasing):ITransitionObject;
	function hideEase(ease:IEasing):ITransitionObject;
	// function autoVisible(value:Bool):ITransitionObject;
	function autoVisObject(object:Dynamic):ITransitionObject;
	function ease(ease:IEasing):ITransitionObject;
	function range(start:Float, fractionDuration:Float):ITransitionObject;
	function start(value:Float):ITransitionObject;
	function end(value:Float):ITransitionObject;
}
