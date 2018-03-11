.. Modified I. Kavcic Met Office
.. _dynamo0.3-api:

dynamo0.3 API
=============

This section describes the dynamo0.3 application programming interface
(API). This API explains what a user needs to write in order to make
use of the dynamo0.3 API in PSyclone.

As with all PSyclone API's the dynamo0.3 API specifies how a user
needs to write the algorithm layer and the kernel layer to allow
PSyclone to generate the PSy layer. These algorithm and kernel API's
are discussed separately in the following sections.

.. _dynamo0.3-api-algorithm:

Algorithm
---------

The general requirements for the structure of an Algorithm are explained
in the :ref:`algorithm-layer` section. This section explains the
dynamo0.3-specific specialisations and extensions.

.. _dynamo0.3-example:

Example
+++++++

An example dynamo0.3 API invoke call is given below with various
different types of objects supported by the API. These different
objects and their use are discussed in the following sections.

::

  real(kind=r_def)      	 :: scalar1
  integer(kind=i_def)   	 :: stencil_extent
  type(field_type)      	 :: field1, field2, field3
  type(quadrature_type) 	 :: qr
  type(operator_type)   	 :: operator1
  type(columnwise_operator_type) :: cma_op1
  ...
  call invoke( kernel1(field1, field2, operator1, qr),           &
               builtin1(scalar1, field2, field3),                &
               kernel2(field1, stencil_extent, field3, scalar1), &
	       assembly_kernel(cma_op1, operator1),              &
               name="some calculation"                           &
             )

Please see the :ref:`algorithm-layer` section for a description of the
``name`` argument.

Field
+++++

.. note:: To be written.

Field Vector
++++++++++++

.. note:: To be written.

Scalar
++++++

In Dynamo 0.3 API a scalar is a single value variable that can be
either real or integer. Real scalars are identified with ``GH_REAL``
and integer scalars are identified with ``GH_INTEGER`` metadata.

Operator
++++++++

Represents a matrix constructed on a per-cell basis using Local
Matrix Assembly (LMA).

Column-Wise Operator
++++++++++++++++++++

The Dynamo 0.3 API has support for the construction and use of
column-wise/Column Matrix Assembly (CMA) operators. As the name
suggests, these are operators constructed for a whole column of the
mesh. These are themselves constructed from the Local Matrix Assembly
(LMA) operators of each cell in the column. The rules governing
Kernels that have CMA operators as arguments are given in the
:ref:`dynamo0.3-kernel` section below.

There are three recognised Kernel types involving CMA operations;
construction, application (including inverse application) and
matrix-matrix. The following example sketches-out what the use
of such kernels might look like in the Algorithm layer:
::

  use field_mod, only: field_type
  use operator_mod, only : operator_type, columnwise_operator_type
  type(field_type) :: field1, field2, field3
  type(operator_type) :: lma_op1, lma_op2
  type(columnwise_operator_type) :: cma_op1, cma_op2, cma_op3
  real(kind=r_def) :: alpha
  ...
  call invoke(                                                    &
          assembly_kernel(cma_op1, lma_op1, lma_op2),             &
          assembly_kernel2(cma_op2, lma_op1, lma_op2, field3),    &
          apply_kernel(field1, field2, cma_op1),                  &
          matrix_matrix_kernel(cma_op3, cma_op1, alpha, cma_op2), &
          apply_kernel(field3, field1, cma_op3),                  &
          name="cma_example")

The above invoke uses two LMA operators to construct the CMA operator
``cma_op1``.  A second CMA operator, ``cma_op2``, is assembled from
the same two LMA operators but also uses a field. The first of these
CMA operators is then applied to ``field2`` and the result stored in
``field1`` (assuming that the meta-data for ``apply_kernel`` specifies
that it is the first field argument that is written to). The two CMA
operators are then combined to produce a third, ``cma_op3``. This is
then applied to ``field1`` and the result stored in ``field3``.

Note that PSyclone identifies the type of kernels performing
Column-Wise operations based on their arguments as described in
meta-data (see :ref:`cma_meta_data_rules` below). The names of the
kernels in the above example are purely illustrative and are not used
by PSyclone when determining kernel type.

.. _quadrature:

Quadrature
++++++++++

Kernels conforming to the Dynamo 0.3 API may require quadrature
information (specified using e.g. ``gh_shape = gh_quadrature_XYoZ`` in
the kernel meta-data - see Section :ref:`gh-shape`). This information
must be passed to the kernel from the Algorithm layer in the form of a
`quadrature_type` object. This must be the last argument passed to the
kernel, e.g.:

::

      type( quadrature_type )   :: qr
      ...
      qr = quadrature_type(element_order+2, GAUSSIAN)
      call invoke(pressure_gradient_kernel_type(rhs_tmp(igh_u), rho, theta, qr),   &
                  kinetic_energy_gradient_kernel_type(rhs_tmp(igh_u), u, chi, qr), &
                  geopotential_gradient_kernel_type(rhs_tmp(igh_u), geopotential, qr))

This quadrature object specifies the set of points at which the 
basis/differential-basis functions required by the kernel are to be evaluated.

.. _dynamo0.3-alg-stencil:

Stencils
++++++++

Kernel metadata may specify that a Kernel performs a stencil operation
on a field. Any such metadata must provide a stencil type. See the
:ref:`dynamo0.3-api-meta-args` section for more details. The supported
stencil types are ``X1D``, ``Y1D``, ``XORY1D`` or ``CROSS``.

If a stencil operation is specified by the Kernel metadata the
algorithm layer must provide the ``extent`` of the stencil (the
maximum distance from the central cell that the stencil extends). The
dynamo0.3 API expects this information to be added as an additional
``integer`` argument immediately after the relevant field when specifying
the Kernel via an ``invoke``.

For example::

  integer :: extent = 2
  call invoke(kernel(field1, field2, extent))

where ``field2`` has kernel metadata specifying that it has a stencil
access.

``extent``  may also be passed as a literal. For example::

  call invoke(kernel(field1, field2, 2))

where, again, ``field2`` has kernel metadata specifying that it has a
stencil access.

.. note:: The stencil extent specified in the Algorithm layer is not the same as the stencil size passed in to the Kernel. The latter contains the number of cells in the stencil which is dependent on both the stencil type and extent.

If the Kernel metadata specifies that the stencil is of type
``XORY1D`` (which means ``X1D`` or ``Y1D``) then the algorithm layer
must specify whether the stencil is ``X1D`` or ``Y1D`` for that
particular kernel call. The dynamo0.3 API expects this information to
be added as an additional argument immediately after the relevant
stencil extent argument. The argument should be an ``integer`` with
valid values being ``x_direction`` or ``y_direction``, both being
supplied by the ``LFRic`` infrastructure via the
``flux_direction_mod`` fortran module

For example::

  use flux_direction_mod, only : x_direction
  integer :: direction = x_direction
  integer :: extent = 2
  ! ...
  call invoke(kernel(field1, field2, extent, direction))

``direction`` may also be passed as a literal. For example::

  use flux_direction_mod, only : x_direction
  integer :: extent = 2
  ! ...
  call invoke(kernel(field1, field2, extent, x_direction))

If certain fields use the same value of extent and/or direction then
the same variable, or literal value can be provided.

For example::

  call invoke(kernel1(field1, field2, extent,  field3, extent, direction), &
              kernel2(field1, field2, extent2, field4, extent, direction))

In the above example ``field2`` and ``field3`` in ``kernel1`` and
``field4`` in ``kernel2`` will have the same ``extent`` value but
``field2`` in ``kernel2`` may have a different value. Similarly,
``field3`` in ``kernel1`` and ``field4`` in ``kernel2`` will have the
same ``direction`` value.

An example of the use of stencils is available in ``examples/dynamo0p3/eg5``.

There is currently no attempt to perform type checking in PSyclone so
any errors in the type and/or position of arguments will not be picked
up until compile time. However, PSyclone does check for the correct
number of algorithm arguments. If the wrong number of arguments is
provided then an exception is raised.

For example, running test 19.2 from the dynamo0.3 api test suite gives::

  cd <PSYCLONEHOME>/src/tests
  python ../../src/generator.py test_files/dynamo0p3/19.2_single_stencil_broken.f90 
  "Generation Error: error: expected '5' arguments in the algorithm layer but found '4'.
  Expected '4' standard arguments, '1' stencil arguments and '0' qr_arguments'"

PSy-layer
---------

The general details of the PSy-layer are explained in the
:ref:`PSy-layer` section. This section describes any dynamo0p3 specific
issues.

Module name
+++++++++++

The PSy-layer code is contained within a Fortran module. The name of
the module is determined from the algorithm-layer name with "_psy"
appended. The algorithm-layer name is the algorithm's module name if it
is a module, its subroutine name if it is a subroutine that is not
within a module, or the program name if it is a program.

So, for example, if the algorithm code is contained within a module
called "fred" then the PSy-layer module name will be "fred_psy".

.. _dynamo0.3-kernel:

Kernel
-------

The general requirements for the structure of a Kernel are explained
in the :ref:`kernel-layer` section. In the Dynamo API there are four
different Kernel types; general purpose, CMA, inter-grid and
:ref:`dynamo_built-ins`. For the latter type, PSyclone generates the
source of the kernels.  This section explains the rules for the other
three, user-supplied kernel types and then goes on to describe their
metadata and subroutine arguments.

Rules for all User-Supplied Kernels
+++++++++++++++++++++++++++++++++++

In the following, 'operator' refers to both LMA and CMA operator
types.

 1) A Kernel must have at least one argument that is a field, field
    vector, or operator. This rule reflects the fact that a Kernel
    iterates over a space and therefore must have some representation
    over that space.

 2) The continuity of the iteration space of the Kernel is determined
    from the function space of the modified argument. If more than one
    argument is modified then the iteration space is taken to be the
    largest required by any of those arguments. e.g. if a Kernel
    writes to two fields, the first on W3 (discontinuous) and the
    second on W1 (continuous), then the iteration space of that Kernel
    will be determined by the field on the continuous space.

 3) If the function space of the modified argument(s) cannot be
    determined then they are assumed to be continuous. This is
    the case if any of the modified arguments are declared as ANY_SPACE and
    their actual space cannot be determined statically. This assumption is
    always safe but leads to additional computation if the quantities being
    updated are actually on discontinuous function spaces.

 4) Operators do not have halo operations operating on them as they
    are either cell- (LMA) or column-based (CMA) and therefore act
    like discontinuous fields.

 5) Any Kernel that writes to an operator will have its iteration
    space expanded such that valid values for the operator are
    computed in the level-1 halo.

 6) Any Kernel that reads from an operator must not access halos
    beyond level 1. In this case PSyclone will check that the Kernel
    does not require values beyond the level-1 halo. If it does then
    PSyclone will abort.

Rules specific to General-Purpose Kernels without CMA Operators
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

 1) General-purpose kernels accept arguments of any of the following
    types: field, field vector, LMA operator, scalar integer, scalar
    real.

 2) A Kernel is permitted to write to more than one
    quantity (field or operator) and these quantities may be on the
    same or different function spaces.

 3) A Kernel may not write to a scalar argument. (Only
    :ref:`dynamo_built-ins` are permitted to do this.) Any scalar
    aguments must therefore be declared in the meta-data as
    "GH_READ" - see below.

.. _cma_meta_data_rules:

Rules for Kernels that work with CMA Operators
++++++++++++++++++++++++++++++++++++++++++++++

The Dynamo 0.3 API has support for kernels that assemble, apply (or
inverse-apply) column-wise/Column Matrix Assembly (CMA) operators.
Such operators may also be used by matrix-matrix kernels. There are
thus three types of CMA-related kernels.  Since, by definition, CMA
operators only act on data within a column, they have no horizontal
dependencies. Therefore, kernels that write to them may be
parallelised without colouring.

All three CMA-related kernel types must obey the following rules:

  1) Since a CMA operator only acts within a single column of data,
     stencil operations are not permitted.

  2) No vector quantities (e.g. "GH_FIELD*3" - see below) are
     permitted as arguments.

There are then additional rules specific to each of the three
CMA kernel types. These are described below.

Assembly
########

CMA operators are themselves constructed from Local-Matrix-Assembly
(LMA) operators. Therefore, any kernel which assembles a CMA
operator must obey the following rules:

1) Have one or more LMA operators as read-only arguments.

2) Have exactly one CMA operator argument which must have write access.

3) Other types of argument (e.g. scalars or fields) are permitted but
   must be read-only.

Application and Inverse Application
###################################

Column-wise operators can only be applied to fields. CMA-Application
kernels must therefore:

1) Have a single CMA operator as a read-only argument.

2) Have exactly two field arguments, one read-only and one that is written to.

3) The function spaces of the read and written fields must match the
   from and to spaces, respectively, of the supplied CMA operator.

Matrix-Matrix
#############

A kernel that has just column-wise operators as arguments and zero or
more read-only scalars is identified as performing a matrix-matrix
operation. In this case:

1) Arguments must be CMA operators and, optionally, one or more scalars.

2) Exactly one of the CMA arguments must be written to while all other
   arguments must be read-only.

Rules for Inter-Grid Kernels
++++++++++++++++++++++++++++

1) An inter-grid kernel is identified by the presence of a field argument with
   the optional `mesh_arg` meta-data element (see
   :ref:`dynamo0.3-intergrid-mdata`).

2) An inter-grid kernel is only permitted to have field or field-vector
   arguments.

3) All inter-grid kernel arguments must have the `mesh_arg` meta-data entry.

4) An inter-grid kernel (and metadata) must have at least one field on
   each of the fine and coarse meshes. Specifying all fields as coarse or
   fine is forbidden.

5) Fields on different meshes must always live on different function spaces.

Metadata
++++++++

The code below outlines the elements of the dynamo0.3 API kernel
metadata, 1) 'meta_args', 2) 'meta_funcs', 3) 'gh_shape', 4)
'iterates_over' and 5) 'procedure'.

::

  type, public, extends(kernel_type) :: my_kernel_type
    type(arg_type) :: meta_args(...) = (/ ... /)
    type(func_type) :: meta_funcs(...) = (/ ... /)
    integer :: gh_shape = gh_quadrature_XYoZ
    integer :: iterates_over = cells
  contains
    procedure :: my_kernel_code
  end type

These five metadata elements are discussed in order in the following
sections.

.. _dynamo0.3-api-meta-args:

meta_args
#########

The ``meta_args`` array specifies information about data that the
kernel code expects to be passed to it via its argument list. There is
one entry in the ``meta_args`` array for each **scalar**, **field**,
or **operator** passed into the Kernel and the order that these occur
in the ``meta_args`` array must be the same as they are expected in
the kernel code argument list. The entry must be of ``arg_type`` which
itself contains metadata about the associated argument. The size of
the meta_args array must correspond to the number of **scalars**,
**fields** and **operators** passed into the Kernel.

.. note:: it makes no sense for a Kernel to have only **scalar** arguments (because the PSy layer will call a Kernel for each point in the spatial domain) and PSyclone will reject such Kernels.

For example, if there are a total of 2 **scalar** / **field** /
**operator** entities being passed to the Kernel then the meta_args
array will be of size 2 and there will be two ``arg_type`` entries:

::

  type(arg_type) :: meta_args(2) = (/                                  &
       arg_type( ... ),                                                &
       arg_type( ... )                                                 &
       /)

Argument-metadata (metadata contained within the brackets of an
``arg_type`` entry), describes either a **scalar**, a **field** or an
**operator** (either LMA or CMA).

The first argument-metadata entry describes whether the data that is
being passed is for a real scalar (``GH_REAL``), an integer scalar
(``GH_INTEGER``), a field (``GH_FIELD``) or an operator (either
``GH_OPERATOR`` for LMA or ``GH_COLUMNWISE_OPERATOR`` for CMA). This
information is mandatory.

Additionally, argument-metadata can be used to describe a vector of
fields (see the :ref:`dynamo0.3-api-algorithm` section for more
details). If so, the size of the vector is specified using the
notation ``GH_FIELD*N``, where ``N`` is the size of the vector.

As an example, the following ``meta_args`` metadata describes 4
entries, the first is a real scalar, the next two are fields and the
fourth is an operator. The third entry is a field vector of size 3.

::

  type(arg_type) :: meta_args(4) = (/                                  &
       arg_type(GH_REAL, ...),                                         &
       arg_type(GH_FIELD, ... ),                                       &
       arg_type(GH_FIELD*3, ... ),                                     &
       arg_type(GH_OPERATOR, ...)                                      &
       /)

The second entry to argument-metadata (information contained within
the brackets of an ``arg_type``) describes how the Kernel makes use of
the data being passed into it (the way it is accessed within a
Kernel). This information is mandatory. There are currently 4 possible
values of this metadata ``GH_WRITE``, ``GH_READ``, ``GH_INC`` and
``GH_SUM``. However, not all combinations of metadata entries are
valid and PSyclone will raise an exception if an invalid combination
is specified. Valid combinations are specified later in this section.

* ``GH_WRITE`` indicates the data is modified in the Kernel before
  (optionally) being read.

* ``GH_READ`` indicates that the data is read and is unmodified.

* ``GH_INC`` indicates that different iterations of a Kernel make
  contributions to shared values. For example, values at cell faces
  may receive contributions from cells on either side of the
  face. This means that such a Kernel needs appropriate
  synchronisation (or colouring) to run in parallel.

* ``GH_SUM`` is an example of a reduction and is the only reduction
  currently supported in PSyclone. This metadata indicates that values
  are summed over calls to Kernel code.

For example:

::

  type(arg_type) :: meta_args(4) = (/                                  &
       arg_type(GH_REAL,  GH_SUM),                                     &
       arg_type(GH_FIELD, GH_INC, ... ),                               &
       arg_type(GH_FIELD*3, GH_WRITE, ... ),                           &
       arg_type(GH_OPERATOR, GH_READ, ...)                             &
       /)

.. note:: In the Dynamo 0.3 API only :ref:`dynamo_built-ins` are permitted
          to write to scalar arguments (and hence perform reductions).
          Furthermore, this permission is currently restricted to integer
          scalars (``GH_INTEGER``) as the LFRic infrastructure does not
          yet support integer reductions.

For a scalar the argument metadata contains only these two entries.
However, fields and operators require further entries specifying
function-space information.
The meaning of these further entries differs depending on whether a
field or an operator is being described.

In the case of an operator, the 3rd and 4th arguments describe the
``to`` and ``from`` function spaces respectively. In the case of a
field the 3rd argument specifies the function space that the field
lives on. Supported function spaces are ``w0``, ``w1``, ``w2``, ``w3``,
``wtheta``, ``w2h`` and ``w2v``.

For example, the meta-data for a kernel that applies a Column-wise
operator to a field might look like:

::

  type(arg_type) :: meta_args(3) = (/                     &
       arg_type(GH_FIELD, GH_INC, W1),                    &
       arg_type(GH_FIELD, GH_READ, W2H),                  &
       arg_type(GH_COLUMNWISE_OPERATOR, GH_READ, W1, W2H) &
       /)

In some cases a Kernel may be written so that it works for fields and/or
operators from any type of w2 space i.e. one of ``w2``, ``w2h`` or
``w2v``. In this case the metadata should be specified as being
``any_w2``.

.. Warning:: in the current implementation it is assumed that all
             fields and/or operators specifying ``any_w2`` within a
             kernel will use the **same** function space. It is up to
             the user to ensure this is the case as otherwise invalid
             code would be generated.

It may be that a Kernel is written such that a field and/or operators
may be on/map-between any function space(s). In this case the metadata
should be specified as being one of ``any_space_1``, ``any_space_2``,
..., ``any_space_9``. The reason for having different names is that a
Kernel might be written to allow 2 or more arguments to be able to
support any function space but for a particular call the function
spaces may have to be the same as each other.

In the example below, the first field entry supports any function space but
it must be the same as the operator's ``to`` function space. Similarly,
the second field entry supports any function space but it must be the same
as the operator's ``from`` function space. Note, the metadata does not
forbid ``ANY_SPACE_1`` and ``ANY_SPACE_2`` from being the same.

::

  type(arg_type) :: meta_args(3) = (/                                  &
       arg_type(GH_FIELD, GH_INC, ANY_SPACE_1 ),                       &
       arg_type(GH_FIELD*3, GH_WRITE, ANY_SPACE_2 ),                   &
       arg_type(GH_OPERATOR, GH_READ, ANY_SPACE_1, ANY_SPACE_2)        &
       /)

Note also that the scope of this naming of any-space function spaces is
restricted to the argument list of individual kernels. i.e. if an
Invoke contains say, two kernel calls that each support arguments on
any function space, e.g. ``ANY_SPACE_1``, there is no requirement that
these two function spaces be the same. Put another way, if an Invoke
contained two calls of a kernel with arguments described by the above
meta-data then the first field argument passed to each kernel call
need not be on the same space.

.. note:: A GH_FIELD argument that specifies GH_WRITE as its access
          pattern must be a discontinuous function in the
          horizontal. At the moment that means it must be ``w3`` but
          in the future there will be more discontinuous function
          spaces. A GH_FIELD that specifies GH_INC as its access
          pattern may be continuous in the vertical (and discontinuous
          in the horizontal), continuous in the horizontal (and
          discontinuous in the vertical), or continuous in both. In
          each case the code is the same. However, if a field is
          discontinuous in the horizontal then it will not need
          colouring and, if is described as being on any space, there
          is currently no way to determine this from the metadata
          (unless we can statically determine the space of the field
          being passed in). At the moment this type of Kernel is
          always treated as if it is continuous in the horizontal,
          even if it is not.

Valid Access Modes
^^^^^^^^^^^^^^^^^^

As mentioned earlier, not all combinations of metadata are
valid. Valid combinations are summarised here. All types of data
(``GH_INTEGER``, ``GH_REAL``, ``GH_FIELD``, ``GH_OPERATOR`` and
``GH_COLUMNWISE_OPERATOR``) may be read within a Kernel and this is
specified in metadata using ``GH_READ``. At least one kernel argument
must be listed as being modified. When data is *modified* in a Kernel
then the permitted access modes depend on the type of data it is and
the function space it is on. Valid values are given in the table
below.

======================	============================    =========================
Argument Type     	Function space                  Access type
======================	============================    =========================
*GH_INTEGER*        	*n/a*                           *GH_SUM (Built-ins only)*
GH_REAL           	n/a                             GH_SUM (Built-ins only)
GH_FIELD                Discontinuous (w3)              GH_WRITE
GH_FIELD                Continuous (not w3)             GH_INC
GH_OPERATOR             Any for both 'to' and 'from'    GH_WRITE
GH_COLUMNWISE_OPERATOR  Any for both 'to' and 'from'    GH_WRITE
======================  ============================    =========================

.. note:: As mentioned above, note that only Built-ins may modify
          scalar arguments. *Since the LFRic infrastructure does not
          currently support integer reductions, integer scalar arguments
          are restricted to having read-only access.*

There is no restriction on the number and function-spaces of other
quantities that a general-purpose kernel can modify other than that it
must modify at least one. The rules for kernels involving CMA operators,
however, are stricter and only one argument may be modified (the CMA
operator itself for assembly, a field for CMA-application and a CMA
operator for matrix-matrix kernels). If a kernel writes to quantities
on different function spaces then PSyclone generates loop bounds
appropriate to the largest iteration space. This means that if a
single kernel updates one quantity on a continuous function space and
one on a discontinuous space then the resulting loop will include
cells in the level 1 halo since they are required for a quantity on a
continuous space. As a consequence, any quantities on a discontinuous
space will then be computed redundantly in the level 1 halo. Currently
PSyclone makes no attempt to take advantage of this (by e.g. setting
the appropriate level-1 halo to 'clean').

PSyclone ensures that both CMA and LMA operators are computed
(redundantly) out to the level-1 halo cells. This permits their use in
kernels which modify quantities on continuous function spaces and also
in subsequent redundant computation of other quantities on
discontinuous function spaces. In conjunction with this, PSyclone also
checks (when generating the PSy layer) that any kernels which read
operator values do not do so beyond the level-1 halo. If any such
accesses are found then PSyclone aborts.

Optional Field Metadata
^^^^^^^^^^^^^^^^^^^^^^^

A field entry in the meta_args array may have an optional fourth element.
This element describes either a stencil access or, for inter-grid kernels,
which mesh the field is on. Since an inter-grid kernel is not permitted
to have stencil accesses, these two options are mutually exclusive.
The meta-data for each case is described in the following sections.

Stencil Metadata
________________


Stencil metadata specifies that the corresponding field argument is accessed
as a stencil operation within the Kernel.  Stencil metadata only makes sense
if the associated field is read within a Kernel i.e. it only makes
sense to specify stencil metadata if the first entry is ``GH_FIELD``
and the second entry is ``GH_READ``.

Stencil metadata is written in the following format:

::

  STENCIL(type)

where ``type`` may be one of ``X1D``, ``Y1D``, ``XORY1D`` or
``CROSS``.  As the stencil ``extent`` (the maximum distance from the
central cell that the stencil extends) is not provided in the metadata,
it is expected to be provided by the algorithm writer as part of the
``invoke`` call (see Section :ref:`dynamo0.3-alg-stencil`). As there
is currently no way to specify a fixed extent value for stencils in the
Kernel metadata, Kernels must therefore be written to support
different values of extent (i.e. stencils with a variable number of
cells).

The ``XORY1D`` stencil type indicates that the Kernel can accept
either ``X1D`` or ``Y1D`` stencils. In this case it is up to the
algorithm developer to specify which of these it is from the algorithm
layer as part of the ``invoke`` call (see Section
:ref:`dynamo0.3-alg-stencil`).

For example, the following stencil (with ``extent=2``):

::

  | 4 | 2 | 1 | 3 | 5 |

would be declared as

::

  STENCIL(X1D)

and the following stencil (with ``extent=2``)

::

  |   |   | 9 |   |   |
  |   |   | 5 |   |   |
  | 6 | 2 | 1 | 3 | 7 |
  |   |   | 4 |   |   |
  |   |   | 8 |   |   |

would be declared as

::

  STENCIL(CROSS)

Below is an example of stencil information within the full kernel metadata.

::

  type(arg_type) :: meta_args(3) = (/                                  &
       arg_type(GH_FIELD, GH_INC, W1),                                 &
       arg_type(GH_FIELD, GH_READ, W2H, STENCIL(CROSS)),               &
       arg_type(GH_OPERATOR, GH_READ, W1, W2H)                         &
       /)

There is a full example of this distributed with PSyclone. It may
be found in ``examples/dynamo0p3/eg5``.

.. _dynamo0.3-intergrid-mdata:

Inter-Grid Metadata
___________________


The alternative form of the optional fourth metadata argument for a
field specifies which mesh the associated field is on.  This is
required for inter-grid kernels which perform prolongation or
restriction operations on fields (or field vectors) existing on grids
of different resolutions.

Mesh metadata is written in the following format:

::

  mesh_arg=type

where ``type`` may be one of ``GH_COARSE`` or ``GH_FINE``. Any kernel
having a field argument with this meta-data is assumed to be an
inter-grid kernel and, as such, all of its other arguments (which
must also be fields) must have it specified too. An example of the
metadata for such a kernel is give below:

::

  type(arg_type) :: meta_args(2) = (/                               &
      arg_type(GH_FIELD, GH_INC,  ANY_SPACE_1, mesh_arg=GH_COARSE), &
      arg_type(GH_FIELD, GH_READ, ANY_SPACE_2, mesh_arg=GH_FINE  )  &
      /)

Note that an inter-grid kernel must have at least one field (or field-
vector) argument on each mesh type and that fields that are on different
meshes cannot be on the same function space.


Column-wise Operators (CMA)
^^^^^^^^^^^^^^^^^^^^^^^^^^^

In this section we provide example metadata for each of the three
recognised kernel types involving CMA operators.

Column-wise operators are constructed from cell-wise (local) operators.
Therefore, in order to **assemble** a CMA operator, a kernel must have at
least one read-only LMA operator, e.g.:
::
   
   type(arg_type) :: meta_args(2) = (/                                       &
        arg_type(GH_OPERATOR,            GH_READ,  ANY_SPACE_1, ANY_SPACE_2),&
        arg_type(GH_COLUMNWISE_OPERATOR, GH_WRITE, ANY_SPACE_1, ANY_SPACE_2) &
        /)

CMA operators (and their inverse) are **applied** to fields. Therefore any
kernel of this type must have one read-only CMA operator, one read-only
field and a field that is updated, e.g.:
::
   
   type(arg_type) :: meta_args(3) = (/                                      &
        arg_type(GH_FIELD,    GH_INC,  ANY_SPACE_1),                        &
        arg_type(GH_FIELD,    GH_READ, ANY_SPACE_2),                        &
        arg_type(GH_COLUMNWISE_OPERATOR, GH_READ, ANY_SPACE_1, ANY_SPACE_2) &
        /)

**Matrix-matrix** kernels compute the product/linear combination of CMA
operators. They must therefore have one such operator that is updated while
the rest are read-only. They may also have read-only scalar arguments, e.g.:
::
   
   type(arg_type) :: meta_args(3) = (/                                        &
        arg_type(GH_COLUMNWISE_OPERATOR, GH_WRITE, ANY_SPACE_1, ANY_SPACE_2), &
        arg_type(GH_COLUMNWISE_OPERATOR, GH_READ, ANY_SPACE_1, ANY_SPACE_2),  &
        arg_type(GH_COLUMNWISE_OPERATOR, GH_READ, ANY_SPACE_1, ANY_SPACE_2),  &
        arg_type(GH_REAL, GH_READ) /)

.. note:: The order with which arguments are specified in meta-data for CMA kernels does not affect the process of identifying the type of kernel (whether it is assembly, matrix-matrix etc.)

meta_funcs
##########

The (optional) second component of kernel meta-data specifies
whether any quadrature or evaluator data is required for a given
function space. (If no quadrature or evaluator data is required then
this meta-data should be omitted.) Consider the
following kernel meta-data:

::
   
    type, extends(kernel_type) :: testkern_operator_type
      type(arg_type), dimension(3) :: meta_args =   &
          (/ arg_type(gh_operator,gh_write,w0,w0),  &
             arg_type(gh_field*3,gh_read,w1),       &
             arg_type(gh_integer,gh_read)           &
          /)
      type(func_type) :: meta_funcs(2) =            &
          (/ func_type(w0, gh_basis, gh_diff_basis) &
             func_type(w1, gh_basis)                &
          /)
      integer, parameter :: gh_shape = gh_quadrature_XYoZ
      integer, parameter :: iterates_over = cells
    contains
      procedure() :: code => testkern_operator_code
    end type testkern_operator_type

The ``arg_type`` component of this meta-data describes a kernel that
takes three arguments (an operator, a field and an integer
scalar). Following the ``meta_args`` array we now have a
``meta_funcs`` array. This allows the user to specify that the kernel
requires basis functions (``gh_basis``) and/or the differential of the
basis functions (``gh_diff_basis``) on one or more of the function
spaces associated with the arguments listed in ``meta_args``.  In this
case we require both for the W0 function space but only basis
functions for W1.

.. _gh-shape:

gh_shape
########

If a kernel requires basis or differential-basis functions then the
meta-data must also specify the set of points on which these functions
are required. This information is provided by the ``gh_shape``
component of the meta-data.  Currently PSyclone supports two shapes;
``gh_quadrature_XYoZ`` for Gaussian quadrature points and
``gh_evaluator`` for evaluation at nodal points. For the latter,
the values of the basis/differential-basis functions are computed at
the nodes defined by the function space of the quantity that the
associated kernel is updating. All necessary data is extracted in the
PSy layer and passed to the kernel(s) as required - nothing is
required from the Algorithm layer. If a kernel requires quadrature on
the other hand, the Algorithm writer must supply a ``quadrature_type``
object as the last argument to the kernel (see Section :ref:`quadrature`).

Note that it is an error for kernel meta-data to specify a value for
``gh_shape`` if no basis or differential-basis functions are
required.

iterates over
#############

The fourth type of metadata provided is ``ITERATES_OVER``. This
specifies that the Kernel has been written with the assumption that it
is iterating over the specified entity. For user-supplied kernels this
currently only has one valid value which is ``CELLS``.

Procedure
#########

The fifth and final type of metadata is ``procedure`` metadata. This
specifies the name of the Kernel subroutine that this metadata
describes.

For example:

::

  procedure :: my_kernel_subroutine

Subroutine
++++++++++

.. _stub-generation-rules:

Rules for General-Purpose Kernels
#################################

The arguments to general-purpose kernels (those that do not involve
CMA operators) follow a set of rules which have been specified for
the dynamo0.3 API. These rules are encoded in the ``generate()``
method within the ``ArgOrdering`` abstract class in the
``dynamo0p3.py`` file. The rules, along with PSyclone's naming
conventions, are:

1) If an LMA operator is passed then include the ``cells`` argument.
   ``cells`` is an integer and has intent ``in``.
2) Include ``nlayers``, the number of layers in a column. ``nlayers``
   is an integer and has intent ``in``.
3) For each scalar/field/vector_field/operator in the order specified by
   the meta_args metadata:

    1) if the current entry is a scalar quantity then include the Fortran
       variable in the argument list. The intent is determined from the
       metadata (see :ref:`dynamo0.3-api-meta-args` for an explanation).
    2) if the current entry is a field then include the field array. The
       field array name is currently specified as being
       ``"field_"<argument_position>"_"<field_function_space>``. A field
       array is a real array of type ``r_def`` and dimensioned as the
       unique degrees of freedom for the space that the field is on.
       This value is passed in separately. Again, the intent is determined
       from the metadata (see :ref:`dynamo0.3-api-meta-args`).

       1) If the field entry has a stencil access then add an integer stencil-size argument with intent ``in``. This will supply the number of cells in the stencil.
       2) If the field entry stencil access is of type ``XORY1D`` then add an integer direction argument with intent ``in``.

    3) if the current entry is a field vector then for each dimension of the vector, include a field array. The field array name is specified as being using ``"field_"<argument_position>"_"<field_function_space>"_v"<vector_position>``. A field array in a field vector is declared in the same way as a field array (described in the previous step).
    4) if the current entry is an operator then first include a dimension size. This is an integer. The name of this size is ``<operator_name>"_ncell_3d"``. Next include the operator. This is a real array of type ``r_def`` and is 3 dimensional. The first two dimensions are the local degrees of freedom for the ``to`` and ``from`` function spaces respectively. The third dimension is the dimension size mentioned before. The name of the operator is ``"op_"<argument_position>``. Again the intent is determined from the metadata (see :ref:`dynamo0.3-api-meta-args`).

4) For each function space in the order they appear in the metadata arguments
   (the ``to`` function space of an operator is considered to be before the
   ``from`` function space of the same operator as it appears first in
   lexicographic order)

    1) Include the number of local degrees of freedom (i.e. number per-cell)
       for the function space. This is an integer and has intent ``in``. The
       name of this argument is ``"ndf_"<field_function_space>``.
    2) If there is a field on this space

        1) Include the unique number of degrees of freedom for the function space. This is an integer and has intent ``in``. The name of this argument is ``"undf_"<field_function_space>``.
        2) Include the dofmap for this function space. This is an integer array with intent ``in``. It has one dimension sized by the local degrees of freedom for the function space.

    3) For each operation on the function space (``basis``, ``diff_basis``, ``orientation``) in the order specified in the metadata

        1) If it is a basis or differential basis function, include the associated argument. This is a real array of kind ``r_def`` with intent ``in``. The rank and extents of this array depend upon the ``gh_shape``:

	    1) If ``gh_shape`` is ``gh_evaluator`` then basis and diff basis are ``real`` arrays of rank 3 with extent (``dimension``, ``number_of_dofs``, ``np_xyz``)

            2) If ``gh_shape`` is ``gh_quadrature_xyoz`` then basis and diff basis are ``real`` arrays of rank 4 with extent (``dimension``, ``number_of_dofs``, ``np_xy``, ``np_z``)

           where ``dimension`` is 1 or 3 and depends upon the function space and whether or not it is a basis or a differential basis function. For the former it is (w0=1, w1=3, w2=3, w3=1, wtheta=1, w2h=3, w2v=3, any_w2=3). For the latter it is (w0=3, w1=3, w2=1, w3=3, wtheta=3, w2h=1, w2v=1, any_w2=3). ``number_of_dofs`` is the number of degrees of freedom (dofs) associated with the function space and ``np_*`` are the number of points to be evaluated: i) ``*_xyz`` in all directions (3D); ii) ``*_xy`` in the horizontal plane (2D); iii) ``*_x, *_y`` in the horizontal (1D); and iv) ``*_z`` in the vertical (1D). The name of the argument is ``"basis_"<field_function_space>`` or ``"diff_basis_"<field_function_space>``, as appropriate.

        2) If it is an orientation array, include the associated argument. The argument is an integer array with intent ``in``. There is one dimension of size the local degrees of freedom for the function space. The name of the array is ``"orientation_"<field_function_space>``.

5) If Quadrature or an Evaluator is required (this is the case if any of the function spaces require basis or differential basis functions)

    1) include integer scalar arguments with intent ``in`` that specify the extent of the basis/diff-basis arrays:

       1) If ``gh_shape`` is ``gh_evaluator`` then pass ``n_xyz``
       2) if ``gh_shape`` is ``gh_quadrature_XYoZ`` then pass ``n_xy`` and ``n_z``

    2) if Quadrature is required (``gh_shape`` is of type ``gh_quadrature_*``) then include weights which are real arrays of kind ``r_def``:

       1) If ``gh_quadrature_XYoZ`` pass in ``w_XZ(n_xy)`` and ``w_Z(n_z)``


Rules for CMA Kernels
#####################

Kernels involving CMA operators are restricted to just three types;
assembly, application/inverse-application and matrix-matrix.
We give the rules for each of these in the sections below.

Assembly
^^^^^^^^

An assembly kernel requires the column-banded dofmap for both the to-
and from-function spaces of the CMA operator being assembled as well
as the number of dofs for each of the dofmaps. The full set of rules is:

    1) Include the ``cell`` argument. ``cell`` is an integer and has
       intent ``in``.
    2) Include ``nlayers``, the number of layers in a column. ``nlayers``
       is an integer and has intent ``in``.
    3) Include the number of cells in the 2D mesh, ``ncell_2d``, which is
       an integer with intent ``in``.
    4) Include the total number of cells, ``ncell_3d``, which is an integer
       with intent ``in``.
    5) For each argument in the ``meta_args`` meta-data array:
       
       1) If it is a LMA operator, include a real, 3-dimensional
          array of type ``r_def``. The first two dimensions are the local
          degrees of freedom for the ``to`` and ``from`` spaces,
          respectively. The third dimension is ``ncell_3d``.
	  
       2) If it is a CMA operator, include a real, 3-dimensional array
          of type ``r_def``. The first dimension is is
          ``"bandwidth_"<operator_name>``, the second is
          ``"nrow_"<operator_name>``, and the third is ``ncell_2d``.
	  
	  1) Include the number of rows in the banded matrix.  This is
	     an integer with intent ``in`` and is named as
	     ``"nrow_"<operator_name>``.
          2) If the from-space of the operator is *not* the same as the 
	     to-space then include the number of columns in the banded
	     matrix.  This is an integer with intent ``in`` and is named as
	     ``"ncol_"<operator_name>``.
	  3) Include the bandwidth of the banded matrix. This is an
	     integer with intent ``in`` and is named as
	     ``"bandwidth_"<operator_name>``.
	  4) Include banded-matrix parameter ``alpha``. This is an integer
	     with intent ``in`` and is named as ``"alpha_"<operator_name>``.
	  5) Include banded-matrix parameter ``beta``. This is an integer
	     with intent ``in`` and is named as ``"beta_"<operator_name>``.
	  6) Include banded-matrix parameter ``gamma_m``. This is an integer
	     with intent ``in`` and is named as ``"gamma_m_"<operator_name>``.
	  7) Include banded-matrix parameter ``gamma_p``. This is an integer
	     with intent ``in`` and is named as ``"gamma_p_"<operator_name>``.

       3) If it is a field or scalar argument then include arguments following
          the same rules as for general-purpose kernels. 
	  
    6) For each unique function space in the order they appear in the
       metadata arguments (the ``to`` function space of an operator is
       considered to be before the ``from`` function space of the same
       operator as it appears first in lexicographic order):

       1) Include the number of degrees of freedom per cell for
	  the space. This is an integer with intent ``in``. The name of this
	  argument is ``"ndf_"<arg_function_space>``.

       2) If there is a field on this space then:

	  1) Include the unique number of degrees of freedom for the
 	     function space. This is an integer and has intent ``in``.
             The name of this argument is ``"undf_"<field_function_space>``.

	  2) Include the dofmap for this space. This is an integer array
	     with intent ``in``. It has one dimension sized by the local
	     degrees of freedom for the function space.

	3) If the CMA operator has this space as its to/from space then
	   include the column-banded dofmap, the list of offsets for the
	   to/from-space. This is an integer array of rank 2. The first
	   dimension is ``"ndf_"<arg_function_space>```` and the second
           is ``nlayers``.


Application/Inverse-Application
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A kernel applying a CMA operator requires the column-indirection
dofmap for both the to- and from-function spaces of the CMA
operator. Since it does not have any LMA operator arguments it does
not require the ``ncell_3d`` and ``nlayers`` scalar arguments. (Since a
column-wise operator is, by definition, assembled for a whole column,
there is no loop over levels when applying it.)
The full set of rules is then:

    1) Include the ``cell`` argument. ``cell`` is an integer and has
       intent ``in``.
    2) Include the number of cells in the 2D mesh, ``ncell_2d``, which is
       an integer with intent ``in``.
    3) For each argument in the ``meta_args`` meta-data array:

       1) If it is a field, include the field array. This is a real
          array of kind ``r_def`` and is of rank 1.  The field array name
	  is currently specified as being
	  ``"field_"<argument_position>"_"<field_function_space>``. The
	  extent of the array is the number of unique degrees of freedom
	  for the function space that the field is on.  This value is
	  passed in separately. The intent of the argument is determined
	  from the metadata (see :ref:`dynamo0.3-api-meta-args`).

       2) If it is a CMA operator, include it and its associated
          parameters (see Rule 5 of CMA Assembly kernels).

    4) For each of the unique function spaces encountered in the
       meta-data arguments (the ``to`` function space of an operator
       is considered to be before the ``from`` function space of the
       same operator as it appears first in lexicographic order):

       1) Include the number of degrees of freedom per cell for the associated
	  function space. This is an integer with intent ``in``. The name
	  of this argument is ``"ndf_"<field_function_space>``.
       2) Include the number of unique degrees of freedom for the associated
	  function space. This is an integer with intent ``in``. The name
	  of this argument is ``"undf_"<field_function_space>``.
       3) Include the dofmap for this function space. This is a rank-1 integer
	  array with extent equal to the number of degrees of freedom of
	  the space (``"ndf_"<field_function_space>``).

    5) Include the indirection map for the to-space of the CMA operator.
       This is a rank-1 integer array with extent ``nrow``.
    6) If the from-space of the operator is *not* the same as the to-space
       then include the indirection map for the from-space of the CMA operator.
       This is a rank-1 integer array with extent ``ncol``.

Matrix-Matrix
^^^^^^^^^^^^^

Does not require any dofmaps and also does not require the ``nlayers``
and ``ncell_3d`` scalar arguments. The full set of rules are then:

    1) Include the ``cell`` argument. ``cell`` is an integer and has
       intent ``in``.
    2) Include the number of cells in the 2D mesh, ``ncell_2d``, which is
       an integer with intent ``in``.
    3) For each CMA operator or scalar argument specifed in meta-data:

       1) If it is a CMA operator, include it and its associated
	  parameters (see Rule 5 of CMA Assembly kernels).

       2) If it is a scalar argument include the corresponding Fortran
	  variable in the argument list with intent ``in``.

.. _dynamo_built-ins:

Built-ins
---------

The basic concept of a PSyclone Built-in is described in the
:ref:`built-ins` section.  In the Dynamo 0.3 API, calls to
Built-ins generally follow a convention that the field/scalar written
to comes first in the argument list. Dynamo 0.3 Built-ins must conform to the
following four rules:

 1) Built-in kernels must have one and only one modified (i.e. written
    to) argument.

 2) There must be at least one field in the argument list. This is so
    that we know the number of dofs to iterate over.

 3) Kernel arguments must be either fields or scalars.

 4) All field arguments to a given Built-in must be on the same
    function space. This is because all current Built-ins iterate over
    dofs and therefore all fields should have the same number. It also
    means that we can determine the number of dofs uniquely when a
    scalar is written to.

The Built-ins supported for the Dynamo 0.3 API are listed in the related
subsections, grouped by the mathematical operation they perform. For clarity,
the calculation performed by each Built-in is described using Fortran array
syntax; this does not necessarily reflect the actual implementation of the
Built-in (*e.g.* it could be implemented by PSyclone generating a call to an
optimised maths library).

Naming scheme
+++++++++++++

The supported Built-ins in the Dynamo 0.3 API are named according to the
scheme presented below. Any new Built-in needs to comply with these rules.

    1) Ordering of arguments in Built-ins calls follows
       *LHS (result) <- RHS (operation on arguments)*
       direction, except where a Built-in returns the *LHS* result to one of
       the *RHS* arguments. In that case ordering of arguments remains as in
       the *RHS* expression, with the returning *RHS* argument written as close
       to the *LHS* as it can be without affecting the mathematical expression.

    2) Field names begin with upper case in short form (e.g. **X**, **Y**,
       **Z**) and any case in long form (e.g. **Field1**, **field**).

    3) Scalar names begin with lower case:  e.g. **a**, **b**, are **scalar1**,
       **scalar2**. Special names for scalars are: **constant** (or **c**),
       **innprod** (inner/scalar product of two fields) and **sumfld**
       (sum of a field).

    4) Arguments in Built-ins variable declarations and constructs (PSyclone
       Fortran and Python definitions):

       a) Are always  written in long form and lower case (e.g. **field1**,
	  **field2**, **scalar1**, **scalar2**);
       b) *LHS* result arguments are always listed first;
       c) *RHS* arguments are listed in order of appearance in the mathematical
	  expression, except when one of them is the *LHS* result.

    5) Built-ins names in Fortran consist of:

       1) *RHS* arguments in short form (e.g. **X**, **Y**, **a**, **b**) only;
       2) Descriptive name of mathematical operation on *RHS* arguments in the
	  form  ``<operationname>_<RHSarg>`` for one *RHS* argument or
	  ``<RHSargs>_<operationname>_<RHSargs>`` for more;
       3) Prefix ``"inc_"`` where the result is returned to one of the *RHS*
	  arguments (i.e. ``"inc_"<RHSargs>_<operationname>_<RHSargs>``).

    6) Built-ins names in Python definitions are similar to their Fortran
       counterparts, with a few differences:

       1) Operators and *RHS* arguments are all in upper case (e.g. **X**,
	  **Y**, **A**, **B**, **Plus**, **Minus**);
       2) There are no underscores;
       3) Common prefix is ``"Dyn"``, common suffix is ``"Kern"``.

Addition
++++++++

Built-ins which add (scaled) fields are denoted with the keyword **plus**.

X_plus_Y
########

**X_plus_Y** (*field3*, *field1*, *field2*)


Sums two fields (Z = X + Y): ::
  
  field3(:) = field1(:) + field2(:)

where:

* type(field_type), intent(out) :: *field3*
* type(field_type), intent(in) :: *field1*
* type(field_type), intent(in) :: *field2*

inc_X_plus_Y
############

**inc_X_plus_Y** (*field1*, *field2*)

Adds the second field to the first and returns it (X = X + Y): ::

  field1(:) = field1(:) + field2(:)

where:

* type(field_type), intent(inout) :: *field1*
* type(field_type), intent(in) :: *field2*

aX_plus_Y
#########

**aX_plus_Y** (*field3*, *scalar*, *field1*, *field2*)

Performs Z = aX + Y: ::
   
  field3(:) = scalar*field1(:) + field2(:)

where:

* real(r_def), intent(in) :: *scalar*
* type(field_type), intent(out) :: *field3*
* type(field_type), intent(in) :: *field1*, *field2*

inc_aX_plus_Y
#############

**inc_aX_plus_Y** (*scalar*, *field1*, *field2*)

Performs X = aX + Y (increments the first field): ::
   
  field1(:) = scalar*field1(:) + field2(:)

where:

* real(r_def), intent(in) :: *scalar*
* type(field_type), intent(inout) :: *field1*
* type(field_type), intent(in) :: *field2*

inc_X_plus_bY
#############

**inc_X_plus_bY** (*field1*, *scalar*, *field2*)

Performs X = X + bY (increments the first field): ::

  field1(:) = field1(:) + scalar*field2(:)

where:

* real(r_def), intent(in) :: *scalar*
* type(field_type), intent(inout) :: *field1*
* type(field_type), intent(in) :: *field2*

aX_plus_bY
##########

**aX_plus_bY** (*field3*, *scalar1*, *field1*, *scalar2*, *field2*)

Performs Z = aX + bY: ::
   
  field3(:) = scalar1*field1(:) + scalar2*field2(:)

where:

* real(r_def), intent(in) :: *scalar1*, *scalar2*
* type(field_type), intent(out) :: *field3*
* type(field_type), intent(in) :: *field1*, *field2*

inc_aX_plus_bY
##############

**inc_aX_plus_bY** (*scalar1*, *field1*, *scalar2*, *field2*)

Performs X = aX + bY (increments the first field): ::
   
  field1(:) = scalar1*field1(:) + scalar2*field2(:)

where:

* real(r_def), intent(in) :: *scalar1*, *scalar2*
* type(field_type), intent(inout) :: *field1*
* type(field_type), intent(in) :: *field2*

Subtraction
+++++++++++

Built-ins which subtract (scaled) fields are denoted with the keyword **minus**.

X_minus_Y
#########

**X_minus_Y** (*field3*, *field1*, *field2*)

Subtracts the second field from the first and stores the result in the 
third (Z = X - Y): ::
  
  field3(:) = field1(:) - field2(:)

where:

* type(field_type), intent(out) :: *field3*
* type(field_type), intent(in) :: *field1*
* type(field_type), intent(in) :: *field2*

inc_X_minus_Y
#############

**inc_X_minus_Y** (*field1*, *field2*)

Subtracts the second field from the first and returns it (X = X - Y): ::

  field1(:) = field1(:) - field2(:)

where:

* type(field_type), intent(inout) :: *field1*
* type(field_type), intent(in) :: *field2*

aX_minus_Y
##########

**aX_minus_Y** (*field3*, *scalar*, *field1*, *field2*)

Performs Z = aX - Y: ::
   
  field3(:) = scalar*field1(:) - field2(:)

where:

* real(r_def), intent(in) :: *scalar*
* type(field_type), intent(out) :: *field3*
* type(field_type), intent(in) :: *field1*, *field2*

X_minus_bY
##########

**X_minus_bY** (*field3*, *field1*, *scalar*, *field2*)

Performs Z = X - bY: ::

  field3(:) = field1(:) - scalar*field2(:)

where:

* real(r_def), intent(in) :: *scalar*
* type(field_type), intent(out) :: *field3*
* type(field_type), intent(in) :: *field1*, *field2*

inc_X_minus_bY
##############

**inc_X_minus_bY** (*field1*, *scalar*, *field2*)

Performs X = X - bY (increments the first field): ::

  field1(:) = field1(:) - scalar*field2(:)

where:

* real(r_def), intent(in) :: *scalar*
* type(field_type), intent(inout) :: *field1*
* type(field_type), intent(in) :: *field2*

Multiplication
++++++++++++++

Built-ins which multiply (scaled) fields are denoted with the keyword **times**.

X_times_Y
#########

**X_times_Y** (*field3*, *field1*, *field2*)

Multiplies two fields together and returns the result in a third 
field (Z = X*Y): ::

  field3(:) = field1(:)*field2(:)

where:

* type(field_type), intent(out) :: *field3*
* type(field_type), intent(in) :: *field1*, *field2*

inc_X_times_Y
#############

**inc_X_times_Y** (*field1*, *field2*)

Multiplies the first field by the second and returns it (X = X*Y): ::

  field1(:) = field1(:)*field2(:)

where:

* type(field_type), intent(inout) :: *field1*
* type(field_type), intent(in) :: *field2*

inc_aX_times_Y
##############

**inc_aX_times_Y** (*scalar*, *field1*, *field2*)

Performs X = a*X*Y (increments the first field): ::
   
  field1(:) = scalar*field1(:)*field2(:)

where:

* real(r_def), intent(in) :: *scalar*
* type(field_type), intent(inout) :: *field1*
* type(field_type), intent(in) :: *field2*

Scaling
+++++++

Built-ins which scale fields are technically cases of multiplying a field by a
scalar and are hence also denoted with the keyword **times**.

a_times_X
#########

**a_times_X** (*field2*, *scalar*, *field1*)

Multiplies a field by a scalar and stores the result in a second 
field (Y = a*X): ::
  
  field2(:) = scalar*field1(:)

where:

* real(r_def), intent(in) :: *scalar*
* type(field_type), intent(out) :: *field2*
* type(field_type), intent(in) :: *field1*

inc_a_times_X
#############

**inc_a_times_X** (*scalar*, *field*)

Multiplies a field by a scalar value and returns the field (X = a*X): ::

  field(:) = scalar*field(:)

where:

* real(r_def), intent(in) :: *scalar*
* type(field_type), intent(inout) :: *field*

Division
++++++++

Built-ins which divide (scaled) fields are denoted with the keyword
**divideby**.

X_divideby_Y
############

**X_divideby_Y** (*field3*, *field1*, *field2*)

Divides the first field by the second and returns the result in the 
third (Z = X/Y): ::

  field3(:) = field1(:)/field2(:)

where:

* type(field_type), intent(out) :: *field3*
* type(field_type), intent(in) :: *field1*, *field2*

inc_X_divideby_Y
################

**inc_X_divideby_Y** (*field1*, *field2*)

Divides the first field by the second and returns it (X = X/Y): ::

  field1(:) = field1(:)/field2(:)

where:

* type(field_type), intent(inout) :: *field1*
* type(field_type), intent(in) :: *field2*

Setting to value
++++++++++++++++

Built-ins which set field elements to some value and hence are denoted with
the keyword **setval**.

setval_c
########

**setval_c** (*field*, *constant*)

Sets all elements of the field *field* to the value *constant* (X = c): ::

  field(:) = constant

where:

* type(field_type), intent(out) :: *field*
* real(r_def), intent(in) :: *constant*

.. note:: The field may be on any function space.

setval_X
########

**setval_X** (*field2*, *field1*)

Sets a field *field2* equal to field *field1* (Y = X): ::

  field2(:) = field1(:)

where:

* type(field_type), intent(out) :: *field2*
* type(field_type), intent(in) :: *field1*

Raising to power
++++++++++++++++

Built-ins which raise field elements to an exponent are denoted with the
keyword **powreal** for real exponent or **powint** for integer exponent.

inc_X_powreal_a
###############

**inc_X_powreal_a** (*field*, *rscalar*)

Raises a field to a real scalar value and returns the field (X = X**a): ::

  field(:) = field(:)**rscalar

where:

* type(field_type), intent(inout) :: *field*
* real(r_def), intent(in) :: *rscalar*

inc_X_powint_n
##############

**inc_X_powint_n** (*field*, *iscalar*)

Raises a field to an integer scalar value and returns the field (X = X**n): ::

  field(:) = field(:)**iscalar

where:

* type(field_type), intent(inout) :: *field*
* integer(i_def), intent(in) :: *iscalar*

Inner product
+++++++++++++

Built-ins which calculate the inner product of two fields or of a field with itself
are denoted with the keyword **innerproduct**.

X_innerproduct_Y
################

**X_innerproduct_Y** (*innprod*, *field1*, *field2*)

Computes the inner product of the fields *field1* and *field2*, *i.e.*: ::

  innprod = SUM(field1(:)*field2(:))

where:

* real(r_def), intent(out) :: *innprod*
* type(field_type), intent(in) :: *field1*, *field2*

.. note:: When used with distributed memory this Built-in will trigger
          the addition of a global sum which may affect the
          performance and/or scalability of the code.

X_innerproduct_X
################

**X_innerproduct_X** (*innprod*, *field*)

Computes the inner product of the field *field1* by itself, *i.e.*: ::

  innprod = SUM(field(:)*field(:))

where:

* real(r_def), intent(out) :: *innprod*
* type(field_type), intent(in) :: *field*

.. note:: When used with distributed memory this Built-in will trigger
          the addition of a global sum which may affect the
          performance and/or scalability of the code.

Sum of elements
+++++++++++++++

Built-in which sums the elements of a field is denoted with the keyword *sum*.

sum_X
#####

**sum_X** (*sumfld*, *field*)

Sums all of the elements of the field *field* and returns the result
in the scalar variable *sumfld*: ::
  
  sumfld = SUM(field(:))

where:

* real(r_def), intent(out) :: sumfld
* type(field_type), intent(in) :: field

.. note:: When used with distributed memory this Built-in will trigger
          the addition of a global sum which may affect the
          performance and/or scalability of the code.

Boundary Conditions
-------------------

In the dynamo0.3 API, boundary conditions for a field or LMA operator can
be enforced by the algorithm developer by calling the Kernels
``enforce_bc_type`` or ``enforce_operator_bc_type``,
respectively. These kernels take a field or operator as input and apply
boundary conditions. For example:

::

  call invoke( kernel_type(field1, field2),      &
               enforce_bc_type(field1),          &
	       kernel_with_op_type(field1, op1), &
	       enforce_operator_bc_type(op1)     &
             )

The particular boundary conditions that are applied are not known by
PSyclone, PSyclone simply recognises these kernels by their names and passes
pre-specified dofmap and boundary_value arrays into the kernel
implementations, the contents of which are set by the LFRic
infrastructure.

Up to and including version 1.4.0 of PSyclone, boundary conditions
were applied automatically after a call to ``matrix_vector_type`` if
the field arguments were on a vector function space (one of ``w1``,
``w2``, ``w2h`` or ``w2v``). With the subsequent introduction of the
ability to apply boundary conditions to operators this functionality
is no longer required and has been removed.

Example ``eg4`` in the ``examples/dynamo`` directory includes a call
to ``enforce_bc_kernel_type`` so can be used to see the boundary condition
code that is added by PSyclone. See the ``README`` in the
``examples/dynamo`` directory for instructions on how to run this
example.


Conventions
-----------

There is a convention in the dynamo0.3 API kernel code that if the
name of the operation being performed is ``<name>`` then a kernel file
is ``<name>_mod.[fF90]``, the name of the module inside the kernel
file is ``<name>_mod``, the name of the kernel metadata in the module
is ``<name>_type`` and the name of the kernel subroutine in the module
is ``<name>_code``. PSyclone does not need this convention to be followed apart from the stub generator (see the :ref:`stub-generation` Section ) where the name of the metadata to be parsed is determined from the module name.

The contents of the metadata is also usually declared private but this
does not affect PSyclone.

Finally, the ``procedure`` metadata (located within the kernel
metadata) usually has ``nopass`` specified but again this is ignored
by PSyclone.

Transformations
---------------

This section describes the dynamo-api-specific transformations. In all
cases, excepting **Dynamo0p3RedundantComputationTrans**, these
transformations are specialisations of generic transformations
described in the :ref:`transformations` section. The difference
between these transformations and the generic ones is that these
perform dynamo-api-specific checks to make sure the transformations
are valid. In practice these transformations perform the required
checks then call the generic ones internally.

The use of the dynamo-api-specific transformations is exactly the same
as the equivalent generic ones in all cases excepting
**DynamoLoopFuseTrans**. In this case an additional optional argument
**same_space** has been added to the **apply** method. The reason for
this is to allow loop fusion when one or more of the iteration-spaces
is determined by a function space that is unknown by PSyclone at
compile time. This is the case when the **ANY_SPACE** function space
is specified in the Kernel metadata. By default PSyclone will not
allow loop fusion if it does not know the spaces are the same. The
**same_space** option allows the user to specify that
the spaces are the same. This option should therefore be used with
caution. Note, if PSyclone knows the spaces are different this option
has no effect and the transformation will always raise an exception.

The **Dynamo0p3RedundantComputationTrans** transformation is only valid
for the "Dynamo0p3" API. This is because this API is currently the
only one that supports distributed memory.

The Dynamo-specific transformations currently available are given
below. If the name of a transformation includes "Dynamo0p3" it means
that the transformation is only valid for this particular API. If the
name of the transformation includes "Dynamo" then it should work with
all versions of the Dynamo API.

.. autoclass:: psyclone.transformations.DynamoLoopFuseTrans
    :members:
    :noindex:

.. autoclass:: psyclone.transformations.DynamoOMPParallelLoopTrans
    :members:
    :noindex:

.. autoclass:: psyclone.transformations.Dynamo0p3OMPLoopTrans
    :members:
    :noindex:

.. autoclass:: psyclone.transformations.Dynamo0p3ColourTrans
    :members:
    :noindex:

.. autoclass:: psyclone.transformations.Dynamo0p3RedundantComputationTrans
    :members:
    :noindex:
