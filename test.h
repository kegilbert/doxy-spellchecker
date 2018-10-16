/**
 *  This is a testyboi. C<A()>
 */
class Test {
    int a;
};

/**
 *  Another class is defined here. It is called Testor.
 *  Testor is not a word now is it.
 *
 *  Check it out.
 *  @code
 *      Testor temp();
 *      temp.sub_test(5);
 *  @endcode
 */
class Testor {
    /**
     *  Constructor
     */
    Testor() { } 

    /**
     *  This is a test method
     *
     *  @param  x   Not sure it does something
     *  @return     Returns something or another
     */
    int sub_test(int x);
};

/**
 *  NotI2C class
 */
class NotI2C {

};

/**
 *  Callback<A()>
 */
template<typename R, typename A0>
class Callback<R(A0)> {

};

/**
 *  Abcdef<R(int)>
 */
template<typename R, typename A0>
class Abcdef<R(int)> {

};

