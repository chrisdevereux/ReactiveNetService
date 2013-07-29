//
//  NSNetService+ReactiveNetService.m
//  ReactiveNetService
//
//  Created by Chris Devereux on 29/07/2013.
//
//

#import "NSNetService+ReactiveNetService.h"
#import <objc/runtime.h>

@interface ReactiveNetServiceBrowserDelegate : NSObject <NSNetServiceBrowserDelegate>
@property (strong, readonly, nonatomic) RACSubject *subject;
@end

@interface ReactiveNetServiceDelegate : NSObject <NSNetServiceDelegate>
- (RACSignal *)resolveNetService:(NSNetService *)service timeout:(NSTimeInterval)timeout;
@end

static NSError *
NetServiceError(NSDictionary *errorDict)
{
    NSString *domain = [errorDict[NSNetServicesErrorDomain] intValue] == kCFStreamErrorDomainNetServices ? RACNetServiceErrorDomain : RACNetServiceSystemErrorDomain;
    
    return [NSError errorWithDomain:domain code:[errorDict[NSNetServicesErrorCode] integerValue] userInfo:@{}];
}

@implementation NSNetService (ReactiveNetService)

+ (RACSignal *)rac_servicesOfType:(NSString *)type inDomain:(NSString *)domainString
{
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        
        ReactiveNetServiceBrowserDelegate *delegate = [ReactiveNetServiceBrowserDelegate new];
        NSNetServiceBrowser *browser = [NSNetServiceBrowser new];
        
        browser.delegate = delegate;
        [browser searchForServicesOfType:type inDomain:domainString];
        
        RACDisposable *subjectDisposable = [delegate.subject subscribe:subscriber];
        CFTypeRef delegatePtr = CFBridgingRetain(delegate);
        
        return [RACDisposable disposableWithBlock:^{
            [subjectDisposable dispose];
            [browser stop];
            browser.delegate = nil;
            CFRelease(delegatePtr);
        }];
    }];
}

- (RACSignal *)rac_resolveWithTimeout:(NSTimeInterval)timeout
{
    ReactiveNetServiceDelegate *delegate = [self delegate];
    NSParameterAssert([delegate isKindOfClass:ReactiveNetServiceDelegate.class]);
    
    return [delegate resolveNetService:self timeout:timeout];
}

@end

#pragma mark - Delegate Implementations:

@implementation ReactiveNetServiceBrowserDelegate {
    NSMutableArray *_services;
}

- (id)init
{
    self = [super init];
    if (!self) {
        return nil;
    }
    
    _services = [NSMutableArray new];
    _subject = [RACReplaySubject replaySubjectWithCapacity:1];
    
    return self;
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    static void *delegateKey = &delegateKey;
    
    ReactiveNetServiceDelegate *delegate = [ReactiveNetServiceDelegate new];
    
    aNetService.delegate = delegate;
    objc_setAssociatedObject(aNetService, delegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [_services addObject:aNetService];
    
    if (!moreComing) {
        [_subject sendNext:[[_services copy] rac_sequence]];
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    [_services removeObject:aNetService];
    
    if (!moreComing) {
        [_subject sendNext:[[_services copy] rac_sequence]];
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didNotSearch:(NSDictionary *)errorDict
{
    [_subject sendError:NetServiceError(errorDict)];
}

@end

@implementation ReactiveNetServiceDelegate {
    RACSubject *_didResolve;
    BOOL _resolved;
}

- (RACSignal *)resolveNetService:(NSNetService *)service timeout:(NSTimeInterval)timeout
{
    NSParameterAssert(service.delegate == self);
    
    if (_resolved) {
        return [RACSignal return:service];
    }
    if (_didResolve) {
        return _didResolve;
    }
    
    _didResolve = [RACSubject subject];
    
    [service resolveWithTimeout:timeout];
    return _didResolve;
}

- (void)netServiceDidResolveAddress:(NSNetService *)sender
{
    _resolved = YES;
    [_didResolve sendNext:sender];
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict
{
    [_didResolve sendError:NetServiceError(errorDict)];
}

@end

NSString *const RACNetServiceErrorDomain = @"RACNetServiceErrorDomain";
NSString *const RACNetServiceSystemErrorDomain = @"RACNetServiceSystemErrorDomain";
