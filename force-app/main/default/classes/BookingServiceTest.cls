/**
 * Tests for BookingService.
 *
 * NOTE for demo: this v1 deliberately omits coverage of applyRushFee.
 * The validate-pr workflow's coverage gate will fail until we add the
 * missing test live in front of the audience.
 */
@IsTest
private class BookingServiceTest {

    @IsTest
    static void computePrice_returnsBaseWhenNotRush() {
        BookingService.BookingRequest req = new BookingService.BookingRequest();
        req.customerEmail = 'jane@example.com';
        req.travelDate = Date.today().addDays(30);
        req.basePrice = 100.00;
        req.rush = false;

        Test.startTest();
        Decimal price = BookingService.computePrice(req);
        Test.stopTest();

        System.assertEquals(100.00, price, 'Non-rush booking should return base price');
    }

    @IsTest
    static void computePrice_throwsWhenNull() {
        Test.startTest();
        try {
            BookingService.computePrice(null);
            System.assert(false, 'Expected BookingException');
        } catch (BookingService.BookingException e) {
            System.assert(e.getMessage().contains('null'), 'Wrong error message');
        }
        Test.stopTest();
    }

    @IsTest
    static void computePrice_throwsWhenBasePriceNonPositive() {
        BookingService.BookingRequest req = new BookingService.BookingRequest();
        req.basePrice = 0;
        req.rush = false;

        Test.startTest();
        try {
            BookingService.computePrice(req);
            System.assert(false, 'Expected BookingException');
        } catch (BookingService.BookingException e) {
            System.assert(e.getMessage().contains('positive'), 'Wrong error message');
        }
        Test.stopTest();
    }

    @IsTest
    static void isValidEmail_acceptsWellFormed() {
        System.assertEquals(true, BookingService.isValidEmail('jane@example.com'));
    }

    @IsTest
    static void isValidEmail_rejectsBlank() {
        System.assertEquals(false, BookingService.isValidEmail(''));
        System.assertEquals(false, BookingService.isValidEmail(null));
    }

    @IsTest
    static void applyRushFee_adds25Percent() {
        Test.startTest();
        Decimal result = BookingService.applyRushFee(100.00);
        Test.stopTest();

        Assert.areEqual(125.00, result, 'Rush fee should add 25% to base price');
    }

    @IsTest
    static void applyLoyaltyDiscount_appliesPerYearWithCap() {
        Test.startTest();
        Decimal fiveYear  = BookingService.applyLoyaltyDiscount(100.00, 5);
        Decimal fifteenYear = BookingService.applyLoyaltyDiscount(100.00, 15);
        Decimal zeroYear  = BookingService.applyLoyaltyDiscount(100.00, 0);
        Decimal nullYear  = BookingService.applyLoyaltyDiscount(100.00, null);
        Test.stopTest();

        Assert.areEqual(90.00, fiveYear,    '5 years should give 10% off (90)');
        Assert.areEqual(80.00, fifteenYear, '15 years should be capped at 20% off (80)');
        Assert.areEqual(100.00, zeroYear,   '0 years should return full price');
        Assert.areEqual(100.00, nullYear,   'null years should return full price');
    }
}
