#import <Foundation/Foundation.h>
#import <GTWSWBase/GTWTriple.h>
#import "GTWSPARQLProtocol.h"
#import <GTWSWBase/GTWSPARQLResultsXMLParser.h>

#define BLACKWATCH_FEDERATOR_NAME "GTWSPARQLEngine"
#define BLACKWATCH_FEDERATOR_VERSION "0.0.1"

static NSString* OSVersionNumber ( void ) {
    NSDictionary *version = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
    NSString *productVersion = version[@"ProductVersion"];
    return productVersion;
}

@implementation GTWSPARQLProtocolStore

+ (unsigned)interfaceVersion {
    return 0;
}

+ (NSString*) usage {
    return @"{ \"endpoint\": <URL of SPARQL endpoint> }";
}

- (instancetype) initWithDictionary: (NSDictionary*) dictionary {
    return [self initWithEndpoint:dictionary[@"endpoint"]];
}

- (GTWSPARQLProtocolStore*) initWithEndpoint: (NSString*) endpoint {
    if (self = [self init]) {
        self.endpoint   = endpoint;
    }
    return self;
}

- (NSArray*) getTriplesMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o error:(NSError **)error {
    NSMutableArray* triples = [NSMutableArray array];
    [self enumerateTriplesMatchingSubject:s predicate:p object:o usingBlock:^(id<GTWTriple> t) {
        [triples addObject:t];
    } error:error];
    return triples;
}

- (BOOL) enumerateTriplesMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o usingBlock: (void (^)(id<GTWTriple> t)) block error:(NSError **)error {
    NSString* sparql    = [NSString stringWithFormat:@"SELECT * WHERE { %@ %@ %@ }", s, p, o];
//    NSLog(@">>> %@", sparql);
	NSString* query		= [[[sparql stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"&" withString:@"%26"] stringByReplacingOccurrencesOfString:@";" withString:@"%3B"];
	NSURL* url	= [NSURL URLWithString:[NSString stringWithFormat:@"%@?query=%@", self.endpoint, query]];
	NSMutableURLRequest* req	= [NSMutableURLRequest requestWithURL:url];
	[req setCachePolicy:NSURLRequestReturnCacheDataElseLoad];
	[req setTimeoutInterval:450.0];
    
	NSString* user_agent	= [NSString stringWithFormat:@"%s/%s Darwin/%@", BLACKWATCH_FEDERATOR_NAME, BLACKWATCH_FEDERATOR_VERSION, OSVersionNumber()];
	[req setValue:user_agent forHTTPHeaderField:@"User-Agent"];
	[req setValue:@"application/sparql-results+xml" forHTTPHeaderField:@"Accept"];
    
	NSData* data	= nil;
	NSHTTPURLResponse* resp	= nil;
	NSError* _error			= nil;
    //	NSLog(@"request: %@", req);
	data	= [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:&_error];
    //	NSLog(@"got response with %lu bytes: %@", [data length], [resp allHeaderFields]);
    //	NSLog(@"got response with %lu bytes", [data length]);
	if (data) {
		NSInteger code	= [resp statusCode];
        if (code >= 300) {
//            NSLog(@"error: (%03ld) %@\n", code, [NSHTTPURLResponse localizedStringForStatusCode:code]);
            NSDictionary* headers	= [resp allHeaderFields];
            NSString* type		= headers[@"Content-Type"];
            if (error) {
                if ([type hasPrefix:@"text/"]) {
                    *error  = [NSError errorWithDomain:@"us.kasei.sparql.store.sparql.http" code:code userInfo:@{@"description": [NSHTTPURLResponse localizedStringForStatusCode:code], @"body": [NSString stringWithCString:[data bytes] encoding:NSUTF8StringEncoding]}];
                } else {
                    *error  = [NSError errorWithDomain:@"us.kasei.sparql.store.sparql.http" code:code userInfo:@{@"description": [NSHTTPURLResponse localizedStringForStatusCode:code], @"data": data}];
                }
            }
            return NO;
        } else {
            // TODO: parse the srx data
            GTWSPARQLResultsXMLParser* parser    = [[GTWSPARQLResultsXMLParser alloc] init];
            NSMutableSet* vars  = [NSMutableSet set];
            NSEnumerator* e = [parser parseResultsFromData:data settingVariables:vars];
            for (NSDictionary* r in e) {
                id<GTWTerm> subject     = s;
                id<GTWTerm> predicate   = p;
                id<GTWTerm> object      = o;
                if ([subject conformsToProtocol:@protocol(GTWVariable)]) {
                    subject   = [r objectForKey:subject.value];
                }
                if ([predicate conformsToProtocol:@protocol(GTWVariable)]) {
                    predicate   = [r objectForKey:predicate.value];
                }
                if ([object conformsToProtocol:@protocol(GTWVariable)]) {
                    object   = [r objectForKey:object.value];
                }
                GTWTriple* t    = [[GTWTriple alloc] initWithSubject:subject predicate:predicate object:object];
                block(t);
            }
            return YES;
        }
	} else {
//		NSInteger code	= [resp statusCode];
//		NSLog(@"error: (%03ld) %@\n", code, [NSHTTPURLResponse localizedStringForStatusCode:code]);
//        NSLog(@"... %@", _error);
        if (error) {
            NSLog(@"SPARQL Protocol HTTP error: %@", _error);
            *error  = _error;
        }
        return NO;
	}
}

@end
