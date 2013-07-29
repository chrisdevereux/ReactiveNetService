//
//  NSNetService+ReactiveNetService.m
//  ReactiveNetService
//
//  Created by Chris Devereux on 29/07/2013.
//
//

#import "NSNetService+ReactiveNetService.h"

@interface ReactiveNetServiceBrowserDelegate : NSObject <NSNetServiceBrowserDelegate>
@property (strong, readonly, nonatomic) RACSubject *subject;
@end


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

- (void)dealloc
{
    
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
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

@end