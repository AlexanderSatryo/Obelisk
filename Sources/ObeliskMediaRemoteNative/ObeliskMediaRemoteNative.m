#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "ObeliskMediaRemoteNative.h"

static void *mrHandle = NULL;
static NSMutableDictionary *controllers = nil;
static NSMutableDictionary *lastArtTitleByKey = nil;
static NSMutableDictionary *lastArtPathByKey = nil;
static BOOL isPolling = NO;
static NSDate *lastPollStartTime = nil;

typedef void (*MRRegisterFn)(dispatch_queue_t);
typedef void (*MRGetClientsFn)(dispatch_queue_t, void(^)(CFArrayRef));
typedef void (*MRGetPlayersFn)(id, id, dispatch_queue_t, void(^)(CFArrayRef));
typedef BOOL (*MRSendCommandFn)(uint32_t, id);

static MRRegisterFn regFn = NULL;
static MRGetClientsFn getClients = NULL;
static MRGetPlayersFn getPlayers = NULL;
static MRSendCommandFn globalSendCmd = NULL;

static Class originClass = nil;
static id localOrigin = nil;
static Class playerPathClass = nil;
static Class destClass = nil;
static Class configClass = nil;
static Class reqQueueClass = nil;
static Class controllerClass = nil;

static SEL initSel = NULL;
static SEL reqSel = NULL;
static SEL sendSel = NULL;

static double parseDouble(id val) {
    if (!val || val == [NSNull null]) return 0.0;
    if ([val isKindOfClass:[NSNumber class]]) return [val doubleValue];
    if ([val isKindOfClass:[NSString class]]) {
        NSString *s = [(NSString *)val stringByReplacingOccurrencesOfString:@"," withString:@"."];
        return [s doubleValue];
    }
    return 0.0;
}

static void pollAllPlayers(BOOL forceArtwork);

static void executeCommandLine(NSString *line) {
    NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSArray *parts = [trimmed componentsSeparatedByString:@"|||"];
    if (parts.count < 4 || ![parts[0] isEqualToString:@"CMD"]) return;

    NSString *targetKey = parts[1];
    uint32_t cmdInt = (uint32_t)[parts[2] intValue];
    double paramVal = [parts[3] doubleValue];

    id ctrl = controllers[targetKey];
    if (!ctrl && targetKey.length > 0) {
        NSArray *subparts = [targetKey componentsSeparatedByString:@"|"];
        NSString *targetBundle = subparts.count > 0 ? [subparts[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
        NSString *targetName = subparts.count > 2 ? [subparts[2] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";

        if (targetBundle.length > 0) {
            for (NSString *k in controllers) {
                NSString *kBundle = [k componentsSeparatedByString:@"|"].firstObject ?: @"";
                if ([kBundle caseInsensitiveCompare:targetBundle] == NSOrderedSame) {
                    ctrl = controllers[k];
                    break;
                }
            }
        }
        if (!ctrl && targetName.length > 0) {
            for (NSString *k in controllers) {
                if ([k localizedCaseInsensitiveContainsString:targetName]) {
                    ctrl = controllers[k];
                    break;
                }
            }
        }
    }
    if (!ctrl && targetKey.length == 0) {
        ctrl = controllers.allValues.firstObject;
    }

    NSDictionary *opts = nil;
    if (cmdInt == 24) {
        opts = @{@"kMRMediaRemoteOptionPlaybackPosition": @(paramVal)};
    } else if (cmdInt == 17 || cmdInt == 18) {
        opts = @{@"kMRMediaRemoteOptionSkipInterval": @(fabs(paramVal))};
    }

    if (ctrl) {
        typedef void (*SendFn)(id, SEL, uint32_t, id, void(^)(id));
        SendFn sendCall = (SendFn)objc_msgSend;
        sendCall(ctrl, sendSel, cmdInt, opts, ^(id resp){
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                pollAllPlayers(NO);
            });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                pollAllPlayers(NO);
            });
        });
    } else if (targetKey.length == 0 && globalSendCmd) {
        globalSendCmd(cmdInt, opts);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            pollAllPlayers(NO);
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            pollAllPlayers(NO);
        });
    }
}

static void pollAllPlayers(BOOL forceArtwork) {
    NSDate *now = [NSDate date];
    if (isPolling && !forceArtwork) {
        if ([now timeIntervalSinceDate:lastPollStartTime] > 1.5) {
            isPolling = NO;
        } else {
            return;
        }
    }
    isPolling = YES;
    lastPollStartTime = now;

    if (!getClients) {
        isPolling = NO;
        return;
    }

    getClients(dispatch_get_main_queue(), ^(CFArrayRef arr){
        NSArray *clients = (__bridge NSArray *)arr;
        if (!clients || clients.count == 0) {
            isPolling = NO;
            printf("PLAYERS_JSON:[]\n");
            fflush(stdout);
            return;
        }

        dispatch_group_t group = dispatch_group_create();
        NSMutableArray *results = [NSMutableArray array];
        NSMutableSet *activeKeys = [NSMutableSet set];

        for (id c in clients) {
            NSString *bundleId = [c valueForKey:@"bundleIdentifier"] ?: @"";
            NSString *parentId = [c valueForKey:@"parentApplicationBundleIdentifier"] ?: @"";
            NSString *displayName = [c valueForKey:@"displayName"] ?: @"";

            dispatch_group_enter(group);
            getPlayers(c, localOrigin, dispatch_get_main_queue(), ^(CFArrayRef pArr){
                NSArray *players = (__bridge NSArray *)pArr;
                if (!players || players.count == 0) {
                    dispatch_group_leave(group);
                    return;
                }

                for (NSUInteger idx = 0; idx < players.count; idx++) {
                    id pl = players[idx];
                    NSString *key = [NSString stringWithFormat:@"%@|%@|%@|%lu", bundleId, parentId, displayName, (unsigned long)idx];
                    [activeKeys addObject:key];

                    id ctrl = controllers[key];
                    if (!ctrl) {
                        id pp = [[playerPathClass alloc] init];
                        [pp setValue:localOrigin forKey:@"origin"];
                        [pp setValue:c forKey:@"client"];
                        [pp setValue:pl forKey:@"player"];

                        id dest = [[destClass alloc] init];
                        [dest setValue:pp forKey:@"playerPath"];

                        #pragma clang diagnostic push
                        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        id qReq = [reqQueueClass performSelector:NSSelectorFromString(@"defaultPlaybackQueueRequest")];
                        #pragma clang diagnostic pop
                        [qReq setValue:@(600.0) forKey:@"artworkWidth"];
                        [qReq setValue:@(600.0) forKey:@"artworkHeight"];
                        [qReq setValue:@(YES) forKey:@"includeMetadata"];

                        id cfg = [[configClass alloc] init];
                        [cfg setValue:dest forKey:@"destination"];
                        [cfg setValue:@(YES) forKey:@"requestPlaybackState"];
                        [cfg setValue:@(YES) forKey:@"requestPlaybackQueue"];
                        [cfg setValue:@(YES) forKey:@"requestClientProperties"];
                        if (qReq) {
                            [cfg setValue:qReq forKey:@"playbackQueueRequest"];
                        }

                        ctrl = ((id (*)(id, SEL, id))objc_msgSend)([controllerClass alloc], initSel, cfg);
                        if (ctrl) {
                            controllers[key] = ctrl;
                        }
                    }

                    if (ctrl) {
                        dispatch_group_enter(group);
                        typedef void (*ReqFn)(id, SEL, void(^)(id, NSError*));
                        ReqFn reqCall = (ReqFn)objc_msgSend;
                        reqCall(ctrl, reqSel, ^(id resp, NSError *err){
                            if (!resp) {
                                dispatch_group_leave(group);
                                return;
                            }

                            id item = [resp valueForKey:@"_mostRelevantItem"];
                            if (!item) {
                                dispatch_group_leave(group);
                                return;
                            }
                            id meta = [item valueForKey:@"metadata"];
                            if (!meta) {
                                dispatch_group_leave(group);
                                return;
                            }

                            NSString *title = [meta valueForKey:@"title"] ?: @"";
                            NSString *artist = [meta valueForKey:@"trackArtistName"] ?: @"";
                            NSString *album = [meta valueForKey:@"albumName"] ?: @"";
                            double dur = parseDouble([meta valueForKey:@"duration"]);
                            double calc = parseDouble([meta valueForKey:@"calculatedPlaybackPosition"]);
                            double el = parseDouble([meta valueForKey:@"elapsedTime"]);
                            double rate = parseDouble([meta valueForKey:@"playbackRate"]);
                            int pbState = [[resp valueForKey:@"playbackState"] intValue];

                            if (dur <= 0 && title.length == 0) {
                                dispatch_group_leave(group);
                                return;
                            }

                            BOOL isPlaying = NO;
                            if (pbState == 1) {
                                isPlaying = YES;
                            } else if (pbState == 2 || pbState == 3 || pbState == 4) {
                                isPlaying = NO;
                            } else {
                                isPlaying = (rate > 0.0);
                            }

                            double pos = isPlaying ? (calc > 0 ? calc : el) : (el > 0 ? el : calc);
                            if (dur > 0) {
                                pos = fmin(fmax(pos, 0.0), dur);
                            }

                            NSString *trackIdent = [NSString stringWithFormat:@"%@_%@", title, artist];
                            if (![lastArtTitleByKey[key] isEqualToString:trackIdent]) {
                                lastArtTitleByKey[key] = trackIdent;
                                [lastArtPathByKey removeObjectForKey:key];
                            }

                            NSString *artPath = lastArtPathByKey[key] ?: @"";
                            id artObj = [item valueForKey:@"artwork"];
                            NSData *imgData = [artObj valueForKey:@"imageData"];
                            if (imgData && imgData.length > 0) {
                                NSString *safeName = [[[key stringByReplacingOccurrencesOfString:@"/" withString:@"_"]
                                                       stringByReplacingOccurrencesOfString:@"|" withString:@"_"]
                                                      stringByReplacingOccurrencesOfString:@" " withString:@"_"];
                                NSString *titleHash = [NSString stringWithFormat:@"%lx", (unsigned long)trackIdent.hash];
                                NSString *path = [NSString stringWithFormat:@"/tmp/obelisk_art_%@_%@.tiff", safeName, titleHash];
                                [imgData writeToFile:path atomically:YES];
                                lastArtPathByKey[key] = path;
                                artPath = path;
                            }

                            [results addObject:@{
                                @"key": key,
                                @"bundleId": bundleId,
                                @"parentBundleId": parentId,
                                @"displayName": displayName,
                                @"title": title,
                                @"artist": artist,
                                @"album": album,
                                @"duration": @(dur),
                                @"position": @(pos),
                                @"isPlaying": @(isPlaying),
                                @"artworkPath": artPath
                            }];
                            dispatch_group_leave(group);
                        });
                    }
                }
                dispatch_group_leave(group);
            });
        }

        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            isPolling = NO;
            for (NSString *existingKey in controllers.allKeys) {
                if (![activeKeys containsObject:existingKey]) {
                    [controllers removeObjectForKey:existingKey];
                    [lastArtTitleByKey removeObjectForKey:existingKey];
                    [lastArtPathByKey removeObjectForKey:existingKey];
                }
            }
            if ([NSJSONSerialization isValidJSONObject:results]) {
                NSData *data = [NSJSONSerialization dataWithJSONObject:results options:0 error:nil];
                if (data) {
                    NSString *jsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    printf("PLAYERS_JSON:%s\n", [jsonStr UTF8String]);
                    fflush(stdout);
                }
            }
        });
    });
}

void run_obelisk_mediaremote_sidecar(void) {
    @autoreleasepool {
        setbuf(stdout, NULL);

        mrHandle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
        if (!mrHandle) {
            fprintf(stderr, "Failed to dlopen MediaRemote\n");
            exit(1);
        }

        regFn = (MRRegisterFn)dlsym(mrHandle, "MRMediaRemoteRegisterForNowPlayingNotifications");
        getClients = (MRGetClientsFn)dlsym(mrHandle, "MRMediaRemoteGetNowPlayingClients");
        getPlayers = (MRGetPlayersFn)dlsym(mrHandle, "MRMediaRemoteGetPlayersForClient");
        globalSendCmd = (MRSendCommandFn)dlsym(mrHandle, "MRMediaRemoteSendCommand");

        if (regFn) {
            regFn(dispatch_get_main_queue());
        }

        originClass = NSClassFromString(@"MROrigin");
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        localOrigin = [originClass performSelector:NSSelectorFromString(@"localOrigin")];
        #pragma clang diagnostic pop

        playerPathClass = NSClassFromString(@"MRPlayerPath");
        destClass = NSClassFromString(@"MRDestination");
        configClass = NSClassFromString(@"MRNowPlayingControllerConfiguration");
        reqQueueClass = NSClassFromString(@"MRPlaybackQueueRequest");
        controllerClass = NSClassFromString(@"MRNowPlayingController");

        initSel = NSSelectorFromString(@"initWithConfiguration:");
        reqSel = NSSelectorFromString(@"performRequestWithCompletion:");
        sendSel = NSSelectorFromString(@"sendCommand:options:completion:");

        controllers = [NSMutableDictionary dictionary];
        lastArtTitleByKey = [NSMutableDictionary dictionary];
        lastArtPathByKey = [NSMutableDictionary dictionary];

        // Stdin reading
        dispatch_queue_t stdinQueue = dispatch_queue_create("com.alxstry.obelisk.sidecar.stdin", DISPATCH_QUEUE_SERIAL);
        dispatch_io_t io = dispatch_io_create(DISPATCH_IO_STREAM, fileno(stdin), stdinQueue, ^(int error){});
        if (io) {
            dispatch_io_read(io, 0, SIZE_MAX, stdinQueue, ^(bool done, dispatch_data_t data, int error){
                if (data) {
                    const void *buffer = NULL;
                    size_t size = 0;
                    dispatch_data_t map = dispatch_data_create_map(data, &buffer, &size);
                    if (buffer && size > 0) {
                        NSString *str = [[NSString alloc] initWithBytes:buffer length:size encoding:NSUTF8StringEncoding];
                        NSArray *lines = [str componentsSeparatedByString:@"\n"];
                        for (NSString *line in lines) {
                            if (line.length > 0) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    executeCommandLine(line);
                                });
                            }
                        }
                    }
                    (void)map;
                }
                if (done || error != 0) {
                    exit(0);
                }
            });
        }

        [[NSNotificationCenter defaultCenter] addObserverForName:@"kMRMediaRemoteNowPlayingInfoDidChangeNotification"
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
            pollAllPlayers(NO);
        }];

        [[NSNotificationCenter defaultCenter] addObserverForName:@"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
            pollAllPlayers(NO);
        }];

        pollAllPlayers(YES);

        NSTimer *timer = [NSTimer timerWithTimeInterval:0.25 repeats:YES block:^(NSTimer * _Nonnull t) {
            pollAllPlayers(NO);
        }];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
        [[NSRunLoop mainRunLoop] run];
    }
}

