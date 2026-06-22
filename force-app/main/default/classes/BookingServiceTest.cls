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

    /*
     * Demo: tests for applyRushFee and applyLoyaltyDiscount are deliberately
     * omitted here. Act 2 of the demo uncomments / pastes them in to fix the
     * coverage gate.
     */

    @IsTest
    static void applyRushFee_adds25Percent() {
        System.assertEquals(125.00, BookingService.applyRushFee(100.00));
    }
    
    @IsTest
    static void applyLoyaltyDiscount_appliesPerYearWithCap() {
        System.assertEquals(90.00, BookingService.applyLoyaltyDiscount(100.00, 5));
        System.assertEquals(80.00, BookingService.applyLoyaltyDiscount(100.00, 15));
        System.assertEquals(100.00, BookingService.applyLoyaltyDiscount(100.00, 0));
        System.assertEquals(100.00, BookingService.applyLoyaltyDiscount(100.00, null));
    }
}
