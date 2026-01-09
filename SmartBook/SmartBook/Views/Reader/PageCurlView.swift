// PageCurlView.swift - 卷页翻页效果视图
// 使用 UIPageViewController 实现真正的 3D 翻页效果

import SwiftUI
import UIKit

// MARK: - 卷页效果视图
struct PageCurlView: View {
    let allPages: [BookPage]
    @Binding var currentPageIndex: Int
    let pageWidth: CGFloat
    let pageHeight: CGFloat
    let settings: ReaderSettings
    let onPageChange: () -> Void
    let onTapCenter: () -> Void
    
    var body: some View {
        PageCurlViewController(
            allPages: allPages,
            currentPageIndex: $currentPageIndex,
            pageWidth: pageWidth,
            pageHeight: pageHeight,
            settings: settings,
            onPageChange: onPageChange,
            onTapCenter: onTapCenter
        )
        .ignoresSafeArea()
    }
}

// MARK: - UIPageViewController 包装器
struct PageCurlViewController: UIViewControllerRepresentable {
    let allPages: [BookPage]
    @Binding var currentPageIndex: Int
    let pageWidth: CGFloat
    let pageHeight: CGFloat
    let settings: ReaderSettings
    let onPageChange: () -> Void
    let onTapCenter: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageVC = UIPageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal,
            options: [.spineLocation: NSNumber(value: UIPageViewController.SpineLocation.min.rawValue)]
        )
        
        pageVC.delegate = context.coordinator
        pageVC.dataSource = context.coordinator
        pageVC.view.backgroundColor = UIColor(settings.bgColor)
        
        // 设置初始页面
        if let initialVC = context.coordinator.viewController(at: currentPageIndex) {
            pageVC.setViewControllers([initialVC], direction: .forward, animated: false)
        }
        
        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        pageVC.view.addGestureRecognizer(tapGesture)
        
        return pageVC
    }
    
    func updateUIViewController(_ pageVC: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        
        // 页面索引变化时更新显示
        if let currentVC = pageVC.viewControllers?.first as? PageContentViewController,
           currentVC.pageIndex != currentPageIndex {
            if let newVC = context.coordinator.viewController(at: currentPageIndex) {
                let direction: UIPageViewController.NavigationDirection = currentVC.pageIndex < currentPageIndex ? .forward : .reverse
                pageVC.setViewControllers([newVC], direction: direction, animated: true)
            }
        }
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, UIPageViewControllerDelegate, UIPageViewControllerDataSource {
        var parent: PageCurlViewController
        
        init(_ parent: PageCurlViewController) {
            self.parent = parent
        }
        
        func viewController(at index: Int) -> PageContentViewController? {
            guard index >= 0 && index < parent.allPages.count else { return nil }
            
            let vc = PageContentViewController()
            vc.pageIndex = index
            vc.view.backgroundColor = UIColor(parent.settings.bgColor)
            
            // 使用共享的 PageContentView
            let pageView = PageContentView(
                pageIndex: index,
                allPages: parent.allPages,
                settings: parent.settings,
                width: parent.pageWidth,
                height: parent.pageHeight
            )
            
            let hostingController = UIHostingController(rootView: AnyView(pageView))
            hostingController.view.backgroundColor = .clear
            hostingController.view.frame = vc.view.bounds
            hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            
            vc.addChild(hostingController)
            vc.view.addSubview(hostingController.view)
            hostingController.didMove(toParent: vc)
            
            return vc
        }
        
        // MARK: - UIPageViewControllerDataSource
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let vc = viewController as? PageContentViewController else { return nil }
            return self.viewController(at: vc.pageIndex - 1)
        }
        
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let vc = viewController as? PageContentViewController else { return nil }
            return self.viewController(at: vc.pageIndex + 1)
        }
        
        // MARK: - UIPageViewControllerDelegate
        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            if completed,
               let currentVC = pageViewController.viewControllers?.first as? PageContentViewController {
                parent.currentPageIndex = currentVC.pageIndex
                parent.onPageChange()
            }
        }
        
        // MARK: - 手势处理
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            let width = gesture.view?.bounds.width ?? 0
            
            if location.x < width * 0.25 {
                // 左侧点击 - 上一页
                if parent.currentPageIndex > 0 {
                    parent.currentPageIndex -= 1
                    parent.onPageChange()
                }
            } else if location.x > width * 0.75 {
                // 右侧点击 - 下一页
                if parent.currentPageIndex < parent.allPages.count - 1 {
                    parent.currentPageIndex += 1
                    parent.onPageChange()
                }
            } else {
                // 中间点击 - 显示/隐藏控制栏
                parent.onTapCenter()
            }
        }
    }
}

// MARK: - 页面内容视图控制器
class PageContentViewController: UIViewController {
    var pageIndex: Int = 0
}
