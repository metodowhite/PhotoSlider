//
//  ViewController.swift
//
//  Created by nakajijapan on 3/28/15.
//  Copyright (c) 2015 net.nakajijapan. All rights reserved.
//

import UIKit
import Kingfisher

@objc public protocol PhotoSliderDelegate:NSObjectProtocol {
    optional func photoSliderControllerWillDismiss(viewController: PhotoSliderKit.PhotoSliderViewController)
    optional func photoSliderControllerDidDismiss(viewController: PhotoSliderKit.PhotoSliderViewController)
}

enum PhotoSliderControllerScrollMode:Int {
    case None = 0, Vertical, Horizontal, Rotating
}

public class PhotoSliderViewController: UIViewController, UIScrollViewDelegate {

    var scrollView:UIScrollView!
    var imageURLs:Array<NSURL>?
    var backgroundView:UIView!
    var effectView:UIVisualEffectView!
    var closeButton:UIButton?
    var scrollMode:PhotoSliderControllerScrollMode = .None
    var scrollInitalized = false
    var closeAnimating = false
    var imageViews = Array<PhotoSliderImageView>()

    public var delegate: PhotoSliderDelegate? = nil
    public var visiblePageControl = true
    public var visibleCloseButton = true
    public var currentPage = 0
    public var pageControl = UIPageControl()
    public var backgroundViewColor = UIColor.blackColor()
    
    public init(imageURLs:Array<NSURL>) {
        super.init(nibName: nil, bundle: nil)
        self.imageURLs = imageURLs
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.frame = UIScreen.mainScreen().bounds
        self.view.backgroundColor = UIColor.clearColor()
        self.view.userInteractionEnabled = true

        self.backgroundView = UIView(frame: self.view.bounds)
        self.backgroundView.backgroundColor = backgroundViewColor

        if floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1 {
            self.view.addSubview(self.backgroundView)
        } else {
            self.effectView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.Dark))
            self.effectView.frame = self.view.bounds
            self.view.addSubview(self.effectView)
            self.effectView.addSubview(self.backgroundView)
        }

        // scrollview setting for Item
        self.scrollView = UIScrollView(frame: CGRectMake(0, 0, self.view.bounds.width, self.view.bounds.height))
        self.scrollView.pagingEnabled = true
        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.delegate = self
        self.scrollView.clipsToBounds = false
        self.scrollView.alwaysBounceHorizontal = true
        self.scrollView.alwaysBounceVertical = true
        self.scrollView.scrollEnabled = true
        self.view.addSubview(self.scrollView)

        self.scrollView.contentSize = CGSizeMake(
            CGRectGetWidth(self.view.bounds) * CGFloat(self.imageURLs!.count),
            CGRectGetHeight(self.view.bounds) * 3.0
        )

        let width = CGRectGetWidth(self.view.bounds)
        let height = CGRectGetHeight(self.view.bounds)
        var frame = self.view.bounds
        frame.origin.y = height
        for imageURL in self.imageURLs! {
            let imageView: PhotoSliderImageView = PhotoSliderImageView(frame: frame)
            self.scrollView.addSubview(imageView)
            imageView.loadImage(imageURL)
            frame.origin.x += width
            
            imageViews.append(imageView)
        }
        
        // Page Control
        if self.visiblePageControl {
            self.pageControl.frame = CGRectZero
            self.pageControl.numberOfPages = imageURLs!.count
            self.pageControl.currentPage = 0
            self.pageControl.userInteractionEnabled = false
            self.view.addSubview(self.pageControl)
            self.layoutPageControl()
        }
        
        // Close Button
        if self.visibleCloseButton {
            self.closeButton = UIButton(frame: CGRectZero)
            let imagePath = self.resourceBundle().pathForResource("PhotoSliderClose", ofType: "png")
            self.closeButton!.setImage(UIImage(contentsOfFile: imagePath!), forState: UIControlState.Normal)
            self.closeButton!.addTarget(self, action: "closeButtonDidTap:", forControlEvents: UIControlEvents.TouchUpInside)
            self.closeButton!.imageView?.contentMode = UIViewContentMode.Center;
            self.view.addSubview(self.closeButton!)
            self.layoutCloseButton()
        }
        
        if self.respondsToSelector("setNeedsStatusBarAppearanceUpdate") {
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    override public func viewWillAppear(animated: Bool) {
        self.scrollView.contentOffset = CGPointMake(self.scrollView.bounds.width * CGFloat(self.currentPage), self.scrollView.bounds.height)
        self.scrollInitalized = true
    }
    
    public override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.dismissViewControllerAnimated(true) { () -> Void in
            self.view.removeFromSuperview()
        }
    }
    
    // MARK: - Constraints
    
    func layoutCloseButton() {
        self.closeButton!.translatesAutoresizingMaskIntoConstraints = false
        
        let views = ["closeButton": self.closeButton!]
        let constraintVertical = NSLayoutConstraint.constraintsWithVisualFormat("V:|-22-[closeButton(32@32)]", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views)
        let constraintHorizontal = NSLayoutConstraint.constraintsWithVisualFormat("H:[closeButton]-22-|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views)
        self.view.addConstraints(constraintVertical)
        self.view.addConstraints(constraintHorizontal)
    }
    
    func layoutPageControl() {
        self.pageControl.translatesAutoresizingMaskIntoConstraints = false
        
        let views = ["pageControl": self.pageControl]
        let constraintVertical = NSLayoutConstraint.constraintsWithVisualFormat("V:[pageControl]-22-|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views)
        let constraintCenterX = NSLayoutConstraint.constraintsWithVisualFormat("H:|[pageControl]|", options: NSLayoutFormatOptions.AlignAllCenterX, metrics: nil, views: views)
        self.view.addConstraints(constraintVertical)
        self.view.addConstraints(constraintCenterX)
    }
    
    // MARK: - UIScrollViewDelegate

    var scrollPreviewPoint = CGPointZero;
    public func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        self.scrollPreviewPoint = scrollView.contentOffset
    }

    public func scrollViewDidScroll(scrollView: UIScrollView) {

        if scrollInitalized == false {
            self.generateCurrentPage()
            return
        }
        
        if self.scrollMode == .Rotating {
            return
        }
        
        let offsetX = fabs(scrollView.contentOffset.x - self.scrollPreviewPoint.x)
        let offsetY = fabs(scrollView.contentOffset.y - self.scrollPreviewPoint.y)
        
        if self.scrollMode == .None {
            if (offsetY > offsetX) {
                self.scrollMode = .Vertical;
            } else {
                self.scrollMode = .Horizontal;
            }
        }
        
        if self.scrollMode == .Vertical {
            let offsetHeight = fabs(scrollView.frame.size.height - scrollView.contentOffset.y)
            let alpha = 1.0 - (fabs(offsetHeight) / (scrollView.frame.size.height / 2.0))
            
            self.backgroundView.alpha = alpha
            
            var contentOffset = scrollView.contentOffset
            contentOffset.x = self.scrollPreviewPoint.x
            scrollView.contentOffset = contentOffset
            
            let screenHeight = UIScreen.mainScreen().bounds.size.height
            
            if self.scrollView.contentOffset.y > screenHeight * 1.4 {
                self.closePhotoSlider(true)
            } else if self.scrollView.contentOffset.y < screenHeight * 0.6  {
                self.closePhotoSlider(false)
            }
            
        } else if self.scrollMode == .Horizontal {
            var contentOffset = scrollView.contentOffset
            contentOffset.y = self.scrollPreviewPoint.y
            scrollView.contentOffset = contentOffset
        }
        
        // Save current page index.
        let previousPage = self.pageControl.currentPage
        
        // Update current page index.
        self.generateCurrentPage()
        
        // If page index has changed - reset zoom scale for previous image.
        if previousPage != self.pageControl.currentPage {
            let imageView = imageViews[previousPage]
            imageView.scrollView.zoomScale = imageView.scrollView.minimumZoomScale
        }
    }
    
    func generateCurrentPage() {
        self.currentPage = abs(Int(scrollView.contentOffset.x / scrollView.frame.size.width))

        if fmod(scrollView.contentOffset.x, scrollView.frame.size.width) == 0.0 {
            if self.visiblePageControl {
                self.pageControl.currentPage = self.currentPage
            }
        }
    }
    
    public func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        
        if self.scrollMode == .Vertical {
            
            let velocity = scrollView.panGestureRecognizer.velocityInView(scrollView)
            if velocity.y < -500 {
                self.scrollView.frame = scrollView.frame;
                self.closePhotoSlider(true)
            } else if velocity.y > 500 {
                self.scrollView.frame = scrollView.frame;
                self.closePhotoSlider(false)
            }
            
        }
        
    }
    
    func closePhotoSlider(up:Bool) {
        
        if self.closeAnimating == true {
            return
        }
        self.closeAnimating = true
        
        let screenHeight = UIScreen.mainScreen().bounds.size.height
        let screenWidth = UIScreen.mainScreen().bounds.size.width
        var movedHeight = CGFloat(0)
        
        if self.delegate!.respondsToSelector("photoSliderControllerWillDismiss:") {
            self.delegate!.photoSliderControllerWillDismiss!(self)
        }
        
        if up {
            movedHeight = -screenHeight
        } else {
            movedHeight = screenHeight
        }
        
        UIView.animateWithDuration(
            0.4,
            delay: 0,
            options: UIViewAnimationOptions.CurveEaseOut,
            animations: { () -> Void in
                self.scrollView.frame = CGRectMake(0, movedHeight, screenWidth, screenHeight)
                self.backgroundView.alpha = 0.0
                self.closeButton?.alpha = 0.0
                self.view.alpha = 0.0
            },
            completion: {(result) -> Void in
                self.dissmissViewControllerAnimated(false)
                self.closeAnimating = false
            }
        )
    }
    
    public func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        self.scrollMode = .None
    }
    
    // MARK: - Button Actions
    
    func closeButtonDidTap(sender:UIButton) {

        if self.delegate!.respondsToSelector("photoSliderControllerWillDismiss:") {
            self.delegate!.photoSliderControllerWillDismiss!(self)
        }
        self.dissmissViewControllerAnimated(true)

    }
    
    // MARK: - Private Methods
    
    func dissmissViewControllerAnimated(animated:Bool) {
        self.dismissViewControllerAnimated(animated, completion: { () -> Void in
            
            if self.delegate!.respondsToSelector("photoSliderControllerDidDismiss:") {
                self.delegate!.photoSliderControllerDidDismiss!(self)
            }
            
        })
    }
    
    func resourceBundle() -> NSBundle {
        return NSBundle(forClass: PhotoSliderViewController.self)
    }
    
    // MARK: - UITraitEnvironment
    
    public override func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
        
        self.scrollMode = .Rotating
        
        let contentViewBounds = self.view.bounds
        let height = contentViewBounds.height
        
        // Background View
        self.backgroundView.frame = contentViewBounds
        if floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_7_1 {
            self.effectView.frame = contentViewBounds
        }
        
        // Scroll View
        self.scrollView.contentSize = CGSizeMake(
            contentViewBounds.width * CGFloat(self.imageURLs!.count),
            contentViewBounds.height * 3.0
        )
        self.scrollView.frame = contentViewBounds;
        
        // ImageViews
        var frame = CGRect(x: 0.0, y: contentViewBounds.height, width: contentViewBounds.width, height: contentViewBounds.height)
        for i in 0..<self.scrollView.subviews.count {
            let imageView = self.scrollView.subviews[i] as! PhotoSliderImageView
            
            imageView.frame = frame
            frame.origin.x += contentViewBounds.size.width
            
            imageView.scrollView.frame = contentViewBounds
        }
        
        self.scrollView.contentOffset = CGPointMake(CGFloat(self.currentPage) * contentViewBounds.width, height)
        
        self.scrollMode = .None
    }
    
}
